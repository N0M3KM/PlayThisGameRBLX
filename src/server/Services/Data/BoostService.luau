--!strict
local Config = require("@game/ReplicatedStorage/Shared/Config/Data")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Operations = require("./ProfileOperations")
local ProfileTypes = require("./ProfileTypes")
local BoostService = {}
export type Kind = "Coins" | "XP"
export type Policy = { CoinMultiplier: number, XpMultiplier: number }
export type Multipliers = { Coins: number, XP: number }
export type Api = {
	grant: (
		Operations.Command,
		Kind,
		number,
		Operations.Guard?
	) -> Result.Result<Payloads.TransactionReceipt>,
	getMultipliers: (number) -> Result.Result<Multipliers>,
}

--[=[ Durations and multipliers are injected owner tuning. Repeated grants extend from
	max(now, saved expiry); retries use duration/kind identity rather than computed expiry.
]=]
function BoostService.new(
	boundary: Operations.Boundary,
	engine: Operations.Engine,
	now: () -> number,
	policy: Policy
): Api
	assert(policy.CoinMultiplier >= 1 and policy.CoinMultiplier < math.huge, "Invalid coin multiplier")
	assert(policy.XpMultiplier >= 1 and policy.XpMultiplier < math.huge, "Invalid XP multiplier")
	local coinMultiplier, xpMultiplier = policy.CoinMultiplier, policy.XpMultiplier
	return table.freeze({
		grant = function(
			command: Operations.Command,
			kind: Kind,
			duration: number,
			guard: Operations.Guard?
		): Result.Result<Payloads.TransactionReceipt>
			if
				(kind ~= "Coins" and kind ~= "XP")
				or duration ~= duration
				or duration <= 0
				or duration > Config.MaxInteger
			then
				return Result.failure("InvalidRequest")
			end
			local intent: Operations.Command = {
				TransactionId = command.TransactionId,
				UserId = command.UserId,
				ExpectedRevision = command.ExpectedRevision,
				Reason = "Boost",
				Fingerprint = string.format("boost|%s|%.17g|%s", kind, duration, command.Fingerprint),
			}
			return engine.execute(intent, function(profile: ProfileTypes.Profile): Result.Result<boolean>
				local timestamp = now()
				if timestamp ~= timestamp or timestamp < 0 or timestamp > Config.MaxInteger then
					return Result.failure("Unavailable")
				end
				local old = if kind == "Coins"
					then profile.Boosts.CoinExpiresAt
					else profile.Boosts.XpExpiresAt
				local expiry = math.max(timestamp, old) + duration
				if expiry > Config.MaxInteger then
					return Result.failure("LimitReached")
				end
				if kind == "Coins" then
					profile.Boosts.CoinExpiresAt = expiry
				else
					profile.Boosts.XpExpiresAt = expiry
				end
				return Result.success(true)
			end, guard)
		end,
		getMultipliers = function(userId: number): Result.Result<Multipliers>
			local read = boundary:ReadBoosts(userId)
			if not read.Ok then
				return Result.failure(read.Code)
			end
			local timestamp = now()
			if timestamp ~= timestamp or timestamp < 0 or timestamp > Config.MaxInteger then
				return Result.failure("Unavailable")
			end
			return Result.success(table.freeze({
				Coins = if read.Value.CoinExpiresAt > timestamp then coinMultiplier else 1,
				XP = if read.Value.XpExpiresAt > timestamp then xpMultiplier else 1,
			}))
		end,
	})
end

return table.freeze(BoostService)
