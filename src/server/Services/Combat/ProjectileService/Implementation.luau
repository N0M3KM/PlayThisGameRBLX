--!strict
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Domain = require("@game/ReplicatedStorage/Shared/Contracts/DomainInterfaces")
local Service = require("@game/ReplicatedStorage/Shared/Contracts/Service")
local Types = require("./Types")
local Validate = require("./Validation")
local Implementation = {}
type Record = {
	Request: Payloads.ProjectileRequest,
	Weapon: Types.Weapon,
	Handle: Types.Handle?,
	Cancelled: boolean,
	Ended: boolean,
	Hit: boolean,
}

--[=[ Ammo/cadence admission belongs to GearService; this boundary owns authoritative flight and hits. ]=]
function Implementation.new(
	transport: Types.Transport?,
	adapter: Types.Adapter,
	limits: Types.Limits,
	identity: string
): Domain.ProjectileService
	assert(#identity > 0 and #identity <= 64, "Projectile identity must be a server-session namespace")
	assert(
		Validate.finite(limits.MaxActiveCasts)
			and limits.MaxActiveCasts >= 1
			and limits.MaxActiveCasts % 1 == 0,
		"Invalid cast cap"
	)
	assert(
		Validate.finite(limits.MaxShotsPerRound)
			and limits.MaxShotsPerRound >= 1
			and limits.MaxShotsPerRound % 1 == 0,
		"Invalid shot cap"
	)
	assert(
		Validate.finite(limits.MaxOriginDistance) and limits.MaxOriginDistance >= 0,
		"Invalid origin bound"
	)
	assert(
		Validate.finite(limits.UnitTolerance) and limits.UnitTolerance > 0 and limits.UnitTolerance < 1,
		"Invalid unit tolerance"
	)
	local initialized, started, destroyed, busy, fenced = false, false, false, false, false
	local currentRound: number? = nil
	local closedRound, activeCount, shotCount, sequence = 0, 0, 0, 0
	local seen: { [string]: boolean } = {}
	local casts: { [string]: Record } = {}
	local function finish(id: string)
		local record = casts[id]
		if not record or record.Ended then
			return
		end
		record.Ended = true
		casts[id] = nil
		activeCount -= 1
	end
	local function cancel(id: string): Result.Result<boolean>
		local record = casts[id]
		if not record then
			return Result.success(true)
		end
		record.Cancelled = true
		if not record.Handle then
			return Result.failure("NotReady")
		end
		local ok, outcome = Validate.sync(record.Handle.cancel)
		if not ok or not outcome or not outcome.Ok then
			fenced = true
			return Result.failure("Unavailable")
		end
		finish(id)
		return Result.success(true)
	end
	local function cancelRound(expected: number): Result.Result<boolean>
		if busy then
			return Result.failure("NotReady")
		end
		if currentRound ~= nil and currentRound ~= expected then
			return Result.failure("StaleRound")
		end
		closedRound = math.max(closedRound, expected)
		local ids: { string } = {}
		for id, record in casts do
			if record.Request.Source.RoundId == expected then
				table.insert(ids, id)
			end
		end
		local all = true
		for _, id in ids do
			if not cancel(id).Ok then
				all = false
			end
		end
		if all then
			currentRound, seen, shotCount = nil, {}, 0
		end
		return if all then Result.success(true) else Result.failure("Unavailable")
	end
	local function hit(id: string, instance: unknown)
		local record = casts[id]
		if
			not record
			or record.Cancelled
			or record.Ended
			or record.Hit
			or not started
			or destroyed
			or fenced
		then
			return
		end
		record.Hit = true
		Validate.sync(function()
			local request, weapon = record.Request, record.Weapon
			if
				not adapter.roundActive(request.Source.RoundId)
				or not adapter.current(request.Source, request.GearId)
			then
				return false
			end
			local target = adapter.hitEntity(instance)
			if not target or not Validate.ref(target) or target.RoundId ~= request.Source.RoundId then
				return false
			end
			adapter.applyDamage({
				Source = request.Source,
				Target = target,
				Amount = weapon.Damage,
				Faction = weapon.Faction,
				Kind = "Projectile",
			})
			return true
		end)
	end
	local function cast(request: Payloads.ProjectileRequest): Result.Result<string>
		if
			type(request) ~= "table"
			or not Validate.ref(request.Source)
			or not Validate.point(request.Origin)
			or not Validate.point(request.Direction)
			or not Validate.unit(request.Direction, limits.UnitTolerance)
			or type(request.GearId) ~= "string"
			or #request.GearId == 0
			or #request.GearId > 64
			or type(request.ShotId) ~= "string"
			or #request.ShotId == 0
			or #request.ShotId > 128
		then
			return Result.failure("InvalidRequest")
		end
		local round = request.Source.RoundId
		if round <= closedRound or (currentRound ~= nil and currentRound ~= round) then
			return Result.failure("StaleRound")
		end
		if not adapter.roundActive(round) or not adapter.current(request.Source, request.GearId) then
			return Result.failure("WrongState")
		end
		local shotKey =
			`{#request.Source.Id}:{request.Source.Id}:{request.Source.Generation}:{request.ShotId}`
		if seen[shotKey] then
			return Result.failure("WrongState")
		end
		if activeCount >= limits.MaxActiveCasts or shotCount >= limits.MaxShotsPerRound then
			return Result.failure("LimitReached")
		end
		local found = adapter.weapon(request.Source, request.GearId)
		if not found.Ok then
			return Result.failure(found.Code)
		end
		local weapon = found.Value
		if
			not Validate.finite(weapon.Damage)
			or weapon.Damage <= 0
			or not Validate.finite(weapon.Speed)
			or weapon.Speed <= 0
			or not Validate.finite(weapon.Range)
			or weapon.Range <= 0
			or not Validate.point(weapon.Muzzle)
			or (weapon.Faction ~= "Hostile" and weapon.Faction ~= "Player" and weapon.Faction ~= "Allied")
		then
			return Result.failure("NotReady")
		end
		if Validate.distance(request.Origin, weapon.Muzzle) > limits.MaxOriginDistance then
			return Result.failure("InvalidRequest")
		end
		-- Once admitted, failed/uncertain launches retain their replay identity for this round.
		currentRound = round
		seen[shotKey], shotCount = true, shotCount + 1
		sequence += 1
		local id = `projectile:{identity}:{sequence}`
		local owned = table.clone(request)
		owned.Source = table.freeze(table.clone(request.Source))
		owned.Origin, owned.Direction =
			table.freeze(table.clone(request.Origin)), table.freeze(table.clone(request.Direction))
		local copied = table.clone(weapon)
		copied.Muzzle = table.freeze(table.clone(weapon.Muzzle))
		local record: Record = {
			Request = table.freeze(owned),
			Weapon = table.freeze(copied),
			Cancelled = false,
			Ended = false,
			Hit = false,
		}
		casts[id], activeCount = record, activeCount + 1
		assert(transport, "Transport preflighted")
		local outcome = transport.fire({
			Origin = copied.Muzzle,
			Direction = owned.Direction,
			Speed = copied.Speed,
			Range = copied.Range,
			RaycastParams = copied.RaycastParams,
		}, function(instance)
			hit(id, instance)
		end, function()
			finish(id)
		end)
		if not outcome.Ok then
			finish(id)
			fenced = true
			return Result.failure(outcome.Code)
		end
		record.Handle = outcome.Value
		return Result.success(id)
	end
	local facade: Domain.ProjectileService = {
		Name = "ProjectileService",
		IsStub = false,
		Init = function(_self: Service.Interface)
			assert(not destroyed, "ProjectileService destroyed")
			initialized = true
		end,
		Start = function(_self: Service.Interface)
			assert(
				initialized and not started and not destroyed and not fenced,
				"Invalid ProjectileService start"
			)
			started = true
		end,
		Stop = function(_self: Service.Interface)
			assert(not busy, "Cannot stop projectile admission inside its mutation")
			if currentRound then
				cancelRound(currentRound)
			end
			started = false
		end,
		Destroy = function(_self: Service.Interface)
			assert(not busy, "Cannot destroy projectile admission inside its mutation")
			if currentRound then
				cancelRound(currentRound)
			end
			started = false
			if transport then
				local ok, result = Validate.sync(transport.destroy)
				if not ok or not result or not result.Ok then
					fenced = true
					return
				end
			end
			destroyed = true
		end,
		IsStarted = function(_self: Service.Interface): boolean
			return started and not destroyed and not fenced
		end,
		Call = function(
			_self: Service.Interface,
			_command: string,
			_args: Service.Arguments?
		): Service.StubResult
			return { Ok = false, Code = "NotReady" }
		end,
		Cast = function(_self: Service.Interface, request: Payloads.ProjectileRequest): Result.Result<string>
			if not started or destroyed or busy or fenced or not transport then
				return Result.failure("NotReady")
			end
			busy = true
			local ok, result = Validate.sync(function()
				return cast(request)
			end)
			busy = false
			if not ok or not result then
				fenced = true
				return Result.failure("Unavailable")
			end
			return result
		end,
		CancelRound = function(_self: Service.Interface, round: number): Result.Result<boolean>
			if not Validate.finite(round) or round < 1 or round % 1 ~= 0 then
				return Result.failure("InvalidRequest")
			end
			return cancelRound(round)
		end,
	}
	return facade
end

return table.freeze(Implementation)
