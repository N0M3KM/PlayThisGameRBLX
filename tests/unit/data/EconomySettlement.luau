--!strict
-- Prepared deterministic partial-settlement regressions; not a live persistence test.
local Result = require("../../../src/shared/Contracts/Result")
local Payloads = require("../../../src/shared/Contracts/Payloads")
local Service = require("../../../src/shared/Contracts/Service")
local Operations = require("../../../src/server/Services/Data/ProfileOperations")
local Template = require("../../../src/server/Services/Data/ProfileTemplate")
local Types = require("../../../src/server/Services/Data/ProfileTypes")
local Transaction = require("../../../src/server/Services/Data/DataService/Transaction")
local Settlement = require("../../../src/server/Services/Data/EconomyService/Settlement")
local RewardContext = require("../../../src/server/Services/Data/EconomyService/RewardContext")
local TransactionEngine = require("../../../src/server/Services/Data/TransactionEngine")
local profiles: { [number]: Types.Profile } = { [1] = Template.new(), [2] = Template.new() }
local disconnected = true
local data = (
	{
		Read = function(_self: Service.Interface, userId: number): Result.Result<Payloads.PlayerDataSnapshot>
			if userId == 2 and disconnected then
				return Result.failure("NotReady")
			end
			return Result.success(
				({ Revision = profiles[userId].Revision } :: unknown) :: Payloads.PlayerDataSnapshot
			)
		end,
	} :: unknown
) :: Operations.Boundary
local engine: Operations.Engine = {
	execute = function(command, mutator, guard)
		local candidate = Template.clone(profiles[command.UserId])
		local receipt = Transaction.applyMutation(candidate, command, mutator, guard)
		if receipt.Ok then
			profiles[command.UserId] = candidate
		end
		return receipt
	end,
}
local first, second = Settlement.empty(1), Settlement.empty(2)
first.Coins, first.XP = 15, 30
second.Coins, second.XP = 35, 70
local plan: Settlement.Plan = {
	Kind = "Boss",
	SourceId = "server-guid:boss-one",
	SnapshotId = "ledger-immutable-1",
	Payouts = { second, first },
}
local function ready(): boolean
	return true
end
local partial = Settlement.apply(data, engine, plan, ready)
assert(not partial.Ok and partial.Code == "NotReady", "Disconnected recipient keeps settlement retriable")
assert(profiles[1].Coins == 15 and profiles[2].Coins == 0, "Only first target was confirmed")
disconnected = false
local retry = Settlement.apply(data, engine, plan, ready)
assert(
	retry.Ok and retry.Value[1].AlreadyApplied and not retry.Value[2].AlreadyApplied,
	"Retry skips saved target and continues pending target"
)
assert(profiles[1].Coins == 15 and profiles[2].Coins == 35, "One boss pool is distributed exactly once")
first.Coins = 16
local changed = Settlement.apply(data, engine, plan, ready)
assert(
	not changed.Ok and changed.Code == "InvalidRequest",
	"Mutable reward intent cannot reuse settlement identity"
)
assert(profiles[1].Coins == 15, "Changed intent cannot add another award")
local oversized: Settlement.Plan = {
	Kind = "Boss",
	SourceId = string.rep("x", 128),
	SnapshotId = "snapshot",
	Payouts = { Settlement.empty(1) },
}
local rejected = Settlement.apply(data, engine, oversized, ready)
assert(
	not rejected.Ok and rejected.Code == "InvalidRequest",
	"Oversized IDs fail instead of being weakly hashed"
)
do
	local fact: Payloads.DamageFact = {
		FactId = "fact",
		Target = { Id = "droid", Generation = 1, RoundId = 1 },
		CreditedUserId = 1,
		ActualHpLoss = 1,
		IsBoss = false,
		Lethal = true,
		DeathId = "death",
	}
	local owned = RewardContext.copyDamageFact(fact)
	fact.DeathId, fact.Target.Id = "changed", "changed"
	assert(
		owned.DeathId == "death" and owned.Target.Id == "droid",
		"Provider must receive an owned fact identity"
	)
	local boss: Payloads.BossSettlement = {
		SettlementId = "boss",
		Entity = { Id = "boss", Generation = 1, RoundId = 1 },
		Contributions = { [1] = 100 },
	}
	local ownedBoss = RewardContext.copyBossSettlement(boss)
	boss.Contributions[1], boss.Entity.Generation = 1, 2
	assert(
		ownedBoss.Contributions[1] == 100 and ownedBoss.Entity.Generation == 1,
		"Provider must receive an owned ledger and entity"
	)
	local round: Payloads.RoundOutcome =
		{ SettlementId = "round", RoundId = 1, Reason = "Survived", Survivors = { 1 } }
	local ownedRound = RewardContext.copyRoundOutcome(round)
	round.Survivors[1] = 2
	assert(
		ownedRound.Survivors[1] == 1 and table.isfrozen(ownedRound.Survivors),
		"Provider eligibility snapshot must be frozen"
	)
end

do
	local commands: { Operations.Command } = {}
	local boundary = (
		{
			ApplyMutation = function(
				_self: Service.Interface,
				intent: Operations.Command,
				_mutator: Operations.Mutator,
				_guard: Operations.Guard?
			): Result.Result<Payloads.TransactionReceipt>
				table.insert(commands, intent)
				if #commands == 1 then
					coroutine.yield()
				end
				return Result.success({
					TransactionId = intent.TransactionId,
					Revision = 1,
					AlreadyApplied = false,
				})
			end,
		} :: unknown
	) :: Operations.Boundary
	local queued = TransactionEngine.new(boundary, {
		clock = function()
			return 0
		end,
		wait = function(_seconds)
			coroutine.yield()
		end,
		QueueTimeoutSeconds = 10,
		PollIntervalSeconds = 1,
		MaxPendingPerPlayer = 2,
	})
	local initial: Operations.Command =
		{ UserId = 1, TransactionId = "first", ExpectedRevision = 0, Reason = "Quest", Fingerprint = "first" }
	local nextIntent: Operations.Command = {
		UserId = 1,
		TransactionId = "second",
		ExpectedRevision = 1,
		Reason = "Quest",
		Fingerprint = "second",
	}
	local function mutate(_profile: Types.Profile): Result.Result<boolean>
		return Result.success(true)
	end
	local firstThread = coroutine.create(function()
		queued.execute(initial, mutate)
	end)
	local secondThread = coroutine.create(function()
		queued.execute(nextIntent, mutate)
	end)
	assert(coroutine.resume(firstThread), "First operation must enter the boundary")
	assert(coroutine.resume(secondThread), "Second operation must queue")
	nextIntent.UserId, nextIntent.TransactionId, nextIntent.Fingerprint = 99, "changed", "changed"
	assert(coroutine.resume(firstThread), "First operation must release its queue ticket")
	assert(coroutine.resume(secondThread), "Queued operation must complete")
	assert(
		commands[2].UserId == 1
			and commands[2].TransactionId == "second"
			and commands[2].Fingerprint == "second",
		"FIFO must retain the validated operation identity across yields"
	)
	assert(table.isfrozen(commands[2]), "Boundary must receive an owned frozen command")
end

return true
