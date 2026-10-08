--!strict
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Service = require("@game/ReplicatedStorage/Shared/Contracts/Service")
local DamageLedger = require("@game/ReplicatedStorage/Shared/Util/Combat/DamageLedger")
local Types = require("./Types")
local Validate = require("./Validation")
local Implementation = {}

--[=[ The sole HP writer. Dependencies are authoritative, synchronous server adapters. ]=]
function Implementation.new(
	adapter: Types.Adapter,
	limits: Types.Limits,
	identity: string,
	onFact: ((Payloads.DamageFact) -> ())?
): Types.Damage
	assert(#identity > 0 and #identity <= 64, "Damage identity must be a server-session namespace")
	for _, limit in
		{
			limits.MaxEntitiesPerRound,
			limits.MaxFactsPerEntity,
			limits.MaxContributorsPerEntity,
			limits.MaxRoundPlayers,
		}
	do
		assert(Validate.finite(limit) and limit >= 1 and limit % 1 == 0, "Invalid damage capacity")
	end
	local initialized, started, destroyed, busy = false, false, false, false
	local roundId: number? = nil
	local ledgers: { [string]: DamageLedger.Ledger } = {}
	local stats: { [number]: Payloads.RoundStat } = {}
	local entityCount, playerCount, sequence = 0, 0, 0
	local function clear()
		roundId = nil
		ledgers, stats = {}, {}
		entityCount, playerCount = 0, 0
	end
	local function roundReady(expected: number): boolean
		return started and not destroyed and roundId == expected
	end
	local function playerStats(userId: number): Payloads.RoundStat
		local existing = stats[userId]
		if existing then
			return existing
		end
		local value = { UserId = userId, Kills = 0, Damage = 0, Assists = 0 }
		stats[userId] = value
		playerCount += 1
		return value
	end
	local function apply(request: Payloads.DamageRequest): Result.Result<Payloads.DamageFact>
		if
			type(request) ~= "table"
			or not Validate.ref(request.Target)
			or not request.Source
			or not Validate.ref(request.Source)
			or type(request.Amount) ~= "number"
			or not Validate.finite(request.Amount)
			or request.Amount <= 0
			or (
				request.Kind ~= "Melee"
				and request.Kind ~= "Projectile"
				and request.Kind ~= "Explosion"
				and request.Kind ~= "Ability"
			)
		then
			return Result.failure("InvalidRequest")
		end
		if not roundReady(request.Target.RoundId) then
			return Result.failure("StaleRound")
		end
		if request.Source.RoundId ~= roundId or not adapter.roundActive(request.Target.RoundId) then
			return Result.failure("WrongState")
		end
		local sourceResult, targetResult = adapter.resolve(request.Source), adapter.resolve(request.Target)
		if not sourceResult.Ok or not targetResult.Ok then
			return Result.failure("UnknownId")
		end
		local source, target = table.clone(sourceResult.Value), table.clone(targetResult.Value)
		if not Validate.entity(source, request.Source) or not Validate.entity(target, request.Target) then
			return Result.failure("Unavailable")
		end
		source.Ref, target.Ref = table.freeze(table.clone(source.Ref)), table.freeze(table.clone(target.Ref))
		table.freeze(source)
		table.freeze(target)
		if
			source.Hp <= 0
			or target.Hp <= 0
			or Validate.same(source.Ref, target.Ref)
			or (source.Faction == "Hostile") == (target.Faction == "Hostile")
		then
			return Result.failure("WrongState")
		end
		if request.Kind == "Projectile" and target.BulletImmune then
			return Result.failure("WrongState")
		end
		local userId = if source.Faction ~= "Hostile" and target.Faction == "Hostile"
			then source.OwnerUserId
			else nil
		if userId and not stats[userId] and playerCount >= limits.MaxRoundPlayers then
			return Result.failure("LimitReached")
		end
		local key = Validate.key(target.Ref)
		local ledger = ledgers[key]
		if not ledger then
			if entityCount >= limits.MaxEntitiesPerRound then
				return Result.failure("LimitReached")
			end
			ledger = DamageLedger.new({
				MaxFacts = limits.MaxFactsPerEntity,
				MaxContributors = limits.MaxContributorsPerEntity,
			})
		end
		local capacity = ledger.canRecord(userId)
		if not capacity.Ok then
			return Result.failure(capacity.Code)
		end
		local modifiers = adapter.modifiers(source, target, request)
		if not modifiers.Ok then
			return Result.failure(modifiers.Code)
		end
		local dealt, taken = modifiers.Value.Dealt, modifiers.Value.Taken
		local amount = request.Amount * dealt * taken
		if
			not Validate.finite(dealt)
			or not Validate.finite(taken)
			or dealt < 0
			or taken < 0
			or not Validate.finite(amount)
			or amount <= 0
		then
			return Result.failure("InvalidRequest")
		end
		if
			userId
			and stats[userId]
			and stats[userId].Damage + math.min(target.Hp, amount) > 9007199254740991
		then
			return Result.failure("LimitReached")
		end
		local outcome = adapter.writeHp(target, target.Hp, math.max(0, target.Hp - amount))
		if not outcome.Ok then
			return Result.failure(outcome.Code)
		end
		if not Validate.finite(outcome.Value) or outcome.Value < 0 or outcome.Value >= target.Hp then
			return Result.failure("Unavailable")
		end
		sequence += 1
		local lethal = outcome.Value == 0
		local fact: Payloads.DamageFact = table.freeze({
			FactId = `damage:{identity}:{sequence}`,
			Target = table.freeze(table.clone(target.Ref)),
			CreditedUserId = userId,
			ActualHpLoss = target.Hp - outcome.Value,
			IsBoss = target.IsBoss,
			Lethal = lethal,
			DeathId = if lethal then `death:{identity}:{sequence}` else nil,
		})
		local recorded = ledger.record(fact)
		assert(recorded.Ok, "Preflighted damage must fit its ledger")
		if not ledgers[key] then
			ledgers[key] = ledger
			entityCount += 1
		end
		if userId then
			local own = playerStats(userId)
			own.Damage += fact.ActualHpLoss
			if lethal then
				own.Kills += 1
			end
		end
		if lethal and target.Faction == "Hostile" then
			for contributor in ledger.contributions() do
				if contributor ~= userId then
					playerStats(contributor).Assists += 1
				end
			end
		end
		if onFact then
			Validate.sync(function()
				onFact(fact)
				return true
			end)
		end
		return Result.success(fact)
	end
	local facade: Types.Damage = {
		Name = "DamageService",
		IsStub = false,
		Init = function(_self: Service.Interface)
			assert(not destroyed, "DamageService destroyed")
			initialized = true
		end,
		Start = function(_self: Service.Interface)
			assert(initialized and not destroyed and not started, "Invalid DamageService start")
			started = true
		end,
		Stop = function(_self: Service.Interface)
			assert(not busy, "Cannot stop damage inside its mutation")
			started = false
			clear()
		end,
		Destroy = function(_self: Service.Interface)
			assert(not busy, "Cannot destroy damage inside its mutation")
			started, destroyed = false, true
			clear()
		end,
		IsStarted = function(_self: Service.Interface): boolean
			return started and not destroyed
		end,
		Call = function(
			_self: Service.Interface,
			_command: string,
			_arguments: Service.Arguments?
		): Service.StubResult
			return { Ok = false, Code = "NotReady" }
		end,
		BeginRound = function(_self: Service.Interface, expected: number): Result.Result<boolean>
			if not started or destroyed or busy then
				return Result.failure("NotReady")
			end
			if not Validate.finite(expected) or expected < 1 or expected % 1 ~= 0 then
				return Result.failure("InvalidRequest")
			end
			if roundId ~= nil and roundId ~= expected then
				return Result.failure("WrongState")
			end
			roundId = expected
			return Result.success(true)
		end,
		ClearRound = function(_self: Service.Interface, expected: number): Result.Result<boolean>
			if busy or (roundId ~= nil and roundId ~= expected) then
				return Result.failure("StaleRound")
			end
			clear()
			return Result.success(true)
		end,
		Apply = function(
			_self: Service.Interface,
			request: Payloads.DamageRequest
		): Result.Result<Payloads.DamageFact>
			if busy or not started or destroyed then
				return Result.failure("NotReady")
			end
			-- Reentrant requests are fenced for the entire mutation and notification.
			busy = true
			local ok, outcome = Validate.sync(function()
				return apply(request)
			end)
			busy = false
			return if ok and outcome then outcome else Result.failure("Unavailable")
		end,
		GetLedger = function(
			_self: Service.Interface,
			entity: Payloads.EntityRef
		): Result.Result<{ Payloads.DamageFact }>
			if not Validate.ref(entity) or not roundReady(entity.RoundId) then
				return Result.failure("StaleRound")
			end
			local ledger = ledgers[Validate.key(entity)]
			return if ledger then Result.success(ledger.facts()) else Result.failure("UnknownId")
		end,
		GetContributions = function(
			_self: Service.Interface,
			entity: Payloads.EntityRef
		): Result.Result<{ [number]: number }>
			if not Validate.ref(entity) or not roundReady(entity.RoundId) then
				return Result.failure("StaleRound")
			end
			local ledger = ledgers[Validate.key(entity)]
			return if ledger then Result.success(ledger.contributions()) else Result.failure("UnknownId")
		end,
		GetRoundStats = function(
			_self: Service.Interface,
			expected: number
		): Result.Result<{ Payloads.RoundStat }>
			if not roundReady(expected) then
				return Result.failure("StaleRound")
			end
			local output: { Payloads.RoundStat } = {}
			for _, entry in stats do
				table.insert(output, table.freeze(table.clone(entry)))
			end
			table.sort(output, function(a, b)
				return a.UserId < b.UserId
			end)
			return Result.success(table.freeze(output))
		end,
	}
	return facade
end

return table.freeze(Implementation)
