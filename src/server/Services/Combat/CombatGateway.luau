--!strict
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Requests = require("@game/ReplicatedStorage/Shared/Contracts/Requests")
local Schemas = require("@game/ReplicatedStorage/Shared/Contracts/RequestSchemas")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Validation = require("@game/ReplicatedStorage/Shared/Registry/Validation")
local Config = require("@game/ReplicatedStorage/Shared/Config/Combat")
export type Action = "UseGear" | "ReloadGear" | "UseAbility"
export type Options = {
	clock: () -> number,
	state: (number) -> Result.Result<Payloads.PlayerStateSnapshot>,
	active: (number) -> boolean,
	use: (number, Requests.UseGear) -> Result.Result<boolean>,
	reload: (number, Requests.ReloadGear) -> Result.Result<boolean>,
	ability: (number, Requests.UseAbility) -> Result.Result<boolean>,
}
export type Gateway = {
	handle: (number, Action, unknown) -> Result.Result<boolean>,
	remove: (number) -> (),
	destroy: () -> (),
}
type Bucket = {
	Tokens: number,
	UpdatedAt: number,
	Seen: { [string]: boolean },
	Order: { string },
	Busy: boolean,
}
local CombatGateway = {}

-- Server extension points must finish within admission. Closing a suspended thread
-- prevents an old request from resuming after its round or player scope is gone.
local function synchronous<T>(callback: () -> T): (boolean, T?)
	local thread = coroutine.create(callback)
	local ok, value = coroutine.resume(thread)
	if not ok or coroutine.status(thread) ~= "dead" then
		pcall(coroutine.close, thread)
		return false, nil
	end
	return true, value
end

local function commandResult(candidate: unknown): Result.Result<boolean>
	if type(candidate) ~= "table" then
		return Result.failure("Unavailable")
	end
	local value = candidate :: { Ok: unknown, Value: unknown, Code: unknown }
	if value.Ok == true and type(value.Value) == "boolean" then
		return Result.success(value.Value)
	elseif value.Ok == false and Result.isErrorCode(value.Code) then
		return Result.failure(value.Code :: Result.ErrorCode)
	end
	return Result.failure("Unavailable")
end

--[=[ Rate/shape/replay/state gates precede expensive geometry. Player identity comes from the server endpoint. ]=]
function CombatGateway.new(options: Options): Gateway
	local buckets: { [number]: Bucket } = {}
	local count, destroyed = 0, false
	local function handle(userId: number, action: Action, input: unknown): Result.Result<boolean>
		if destroyed or not Validation.playerId(userId, 9007199254740991) then
			return Result.failure("NotReady")
		end
		local clockOk, now = synchronous(options.clock)
		if not clockOk or now == nil or not Validation.finite(now) or now < 0 then
			return Result.failure("Unavailable")
		end
		local bucket = buckets[userId]
		if not bucket then
			if count >= Config.MaxTrackedPlayers then
				return Result.failure("LimitReached")
			end
			bucket = { Tokens = Config.RateCapacity, UpdatedAt = now, Seen = {}, Order = {}, Busy = false }
			buckets[userId], count = bucket, count + 1
		end
		if now < bucket.UpdatedAt then
			return Result.failure("Unavailable")
		end
		bucket.Tokens = math.min(
			Config.RateCapacity,
			bucket.Tokens + (now - bucket.UpdatedAt) * Config.RateRefillPerSecond
		)
		bucket.UpdatedAt = now
		if bucket.Tokens < 1 then
			return Result.failure("RateLimited")
		end
		bucket.Tokens -= 1
		local checked: Result.Result<Requests.UseGear>
		if action == "UseGear" then
			checked = Schemas.useGear(input)
		elseif action == "ReloadGear" or action == "UseAbility" then
			local command = if action == "ReloadGear"
				then Schemas.reloadGear(input)
				else Schemas.useAbility(input)
			if not command.Ok then
				return Result.failure(command.Code)
			end
			local normalized: Requests.UseGear = {
				RequestId = command.Value.RequestId,
				RoundId = command.Value.RoundId,
				CharacterGeneration = command.Value.CharacterGeneration,
				GearSlot = command.Value.GearSlot,
				AimOrigin = nil,
				AimDirection = nil,
			}
			checked = Result.success(normalized)
		else
			return Result.failure("InvalidRequest")
		end
		if not checked.Ok then
			return Result.failure(checked.Code)
		end
		local intent = checked.Value
		if bucket.Seen[intent.RequestId] or bucket.Busy then
			return Result.failure("WrongState")
		end
		-- Recent IDs are an abuse guard; ammo/cooldown and current state remain authoritative after eviction.
		bucket.Seen[intent.RequestId] = true
		table.insert(bucket.Order, intent.RequestId)
		if #bucket.Order > Config.MaxRequestIds then
			local evicted = table.remove(bucket.Order, 1)
			if evicted then
				bucket.Seen[evicted] = nil
			end
		end
		local admitted, admission = synchronous(function(): Result.Result<boolean>
			local state = options.state(userId)
			if not state.Ok or state.Value.UserId ~= userId then
				return Result.failure("NotReady")
			end
			if
				state.Value.RoundId ~= intent.RoundId
				or state.Value.CharacterGeneration ~= intent.CharacterGeneration
			then
				return Result.failure("StaleRound")
			end
			if state.Value.State ~= "InRound" or not options.active(intent.RoundId) then
				return Result.failure("WrongState")
			end
			return Result.success(true)
		end)
		if not admitted or not admission then
			return Result.failure("Unavailable")
		elseif not admission.Ok then
			return Result.failure(admission.Code)
		end
		bucket.Busy = true
		local ok, result = synchronous(function()
			if action == "UseGear" then
				return options.use(userId, intent)
			elseif action == "ReloadGear" then
				return options.reload(userId, intent)
			end
			return options.ability(userId, intent)
		end)
		bucket.Busy = false
		return if ok then commandResult(result) else Result.failure("Unavailable")
	end
	return table.freeze({
		handle = handle,
		remove = function(userId: number)
			if buckets[userId] then
				buckets[userId], count = nil, count - 1
			end
		end,
		destroy = function()
			destroyed = true
			table.clear(buckets)
			count = 0
		end,
	})
end

return table.freeze(CombatGateway)
