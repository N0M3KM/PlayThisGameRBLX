--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Domain = require(Shared.Contracts.DomainInterfaces)
local Payloads = require(Shared.Contracts.Payloads)
local Result = require(Shared.Contracts.Result)
local Service = require(Shared.Contracts.Service)
local Validation = require(Shared.Registry.Validation)
local Config = require(Shared.Config.Data)
local Calculator = require(Shared.Util.Economy.RewardCalculator)
local Scope = require(Shared.Util.Scope)
local Lifecycle = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceLifecycle)
local Operations = require(script.Parent.Parent.ProfileOperations)
local Transaction = require(script.Parent.Parent.DataService.Transaction)
local RewardContext = require(script.Parent.RewardContext)
local Settlement = require(script.Parent.Settlement)
local Implementation = {}

local function safely<T>(callback: () -> Result.Result<T>): Result.Result<T>
	local ok, outcome = pcall(callback)
	return if ok then outcome else Result.failure("Unavailable")
end

local function killPayouts(context: RewardContext.Kill, boss: boolean): Result.Result<{ Settlement.Payout }>
	local calculation = if boss then Calculator.boss(context.Options) else Calculator.nonBoss(context.Options)
	local payouts: { [number]: Settlement.Payout } = {}
	local contributors: { [number]: boolean } = {}
	for _, contribution in context.Options.Contributions do
		contributors[contribution.UserId] = contribution.Damage > 0
	end
	for _, credit in calculation.Payouts do
		local payout = Settlement.empty(credit.UserId)
		payout.Coins, payout.XP = credit.Coins, credit.XP
		payout.Kills = if not boss and context.Options.KillerUserId == credit.UserId then 1 else 0
		payouts[credit.UserId] = payout
	end
	if context.Stats then
		for userId, stats in context.Stats do
			if not contributors[userId] then
				return Result.failure("InvalidRequest")
			end
			local payout = payouts[userId] or Settlement.empty(userId)
			payout.Damage, payout.Assists = stats.Damage, stats.Assists
			payouts[userId] = payout
		end
	end
	local list: { Settlement.Payout } = {}
	for _, payout in payouts do
		table.insert(list, payout)
	end
	return Result.success(list)
end

local function participants(values: { number }): { [number]: boolean }?
	local set: { [number]: boolean } = {}
	local count = 0
	for index, userId in values do
		count += 1
		if
			type(index) ~= "number"
			or index % 1 ~= 0
			or index < 1
			or count > Config.MaxCollectionEntries
			or set[userId]
			or not Validation.playerId(userId, Config.MaxInteger)
		then
			return nil
		end
		set[userId] = true
	end
	for index = 1, count do
		if values[index] == nil then
			return nil
		end
	end
	return if count == #values then set else nil
end

--[=[ No reward context is invented from incomplete wire facts. Providers must retain
	immutable source snapshots so save failures and disconnects can be retried safely.
]=]
function Implementation.new(
	data: Operations.Boundary,
	engine: Operations.Engine,
	provider: RewardContext.Provider
): Domain.EconomyService
	local facade = Lifecycle.new("EconomyService", Scope.new())
	local service = (facade :: unknown) :: Domain.EconomyService
	local function ready(): boolean
		return service:IsStarted() and data:IsStarted()
	end
	service.SettleNonBossKill = function(
		_self: Service.Interface,
		fact: Payloads.DamageFact
	): Result.Result<{ Payloads.TransactionReceipt }>
		if not ready() then
			return Result.failure("NotReady")
		end
		fact = RewardContext.copyDamageFact(fact)
		if
			not fact.Lethal
			or fact.IsBoss
			or not fact.DeathId
			or not Validation.finite(fact.ActualHpLoss)
			or fact.ActualHpLoss <= 0
		then
			return Result.failure("InvalidRequest")
		end
		return safely(function()
			local context = provider.nonBoss(fact)
			if not context.Ok then
				return Result.failure(context.Code)
			end
			if context.Value.Options.KillerUserId ~= fact.CreditedUserId then
				return Result.failure("InvalidRequest")
			end
			if fact.CreditedUserId then
				local credited = false
				for _, entry in context.Value.Options.Contributions do
					if entry.UserId == fact.CreditedUserId and entry.Damage >= fact.ActualHpLoss then
						credited = true
					end
				end
				if not credited then
					return Result.failure("InvalidRequest")
				end
			end
			local payouts = killPayouts(context.Value, false)
			if not payouts.Ok then
				return Result.failure(payouts.Code)
			end
			return Settlement.apply(data, engine, {
				Kind = "Kill",
				SourceId = fact.DeathId :: string,
				SnapshotId = context.Value.SnapshotId,
				Payouts = payouts.Value,
			}, ready)
		end)
	end
	service.SettleBossContributors = function(
		_self: Service.Interface,
		source: Payloads.BossSettlement
	): Result.Result<{ Payloads.TransactionReceipt }>
		if not ready() then
			return Result.failure("NotReady")
		end
		source = RewardContext.copyBossSettlement(source)
		return safely(function()
			local context = provider.boss(source)
			if not context.Ok then
				return Result.failure(context.Code)
			end
			local seen: { [number]: boolean } = {}
			for _, entry in context.Value.Options.Contributions do
				if source.Contributions[entry.UserId] ~= entry.Damage then
					return Result.failure("InvalidRequest")
				end
				seen[entry.UserId] = true
			end
			for userId in source.Contributions do
				if not seen[userId] then
					return Result.failure("InvalidRequest")
				end
			end
			local payouts = killPayouts(context.Value, true)
			if not payouts.Ok then
				return Result.failure(payouts.Code)
			end
			return Settlement.apply(data, engine, {
				Kind = "Boss",
				SourceId = source.SettlementId,
				SnapshotId = context.Value.SnapshotId,
				Payouts = payouts.Value,
			}, ready)
		end)
	end
	service.SettleSurvival = function(
		_self: Service.Interface,
		source: Payloads.RoundOutcome
	): Result.Result<{ Payloads.TransactionReceipt }>
		if not ready() then
			return Result.failure("NotReady")
		end
		source = RewardContext.copyRoundOutcome(source)
		return safely(function()
			local context = provider.survival(source)
			if not context.Ok then
				return Result.failure(context.Code)
			end
			local all = participants(context.Value.Participants)
			local survivors = participants(source.Survivors)
			local rewarded = participants(context.Value.Options.UserIds)
			if not all or not survivors or not rewarded then
				return Result.failure("InvalidRequest")
			end
			for userId in survivors do
				if not all[userId] or not rewarded[userId] then
					return Result.failure("InvalidRequest")
				end
			end
			for userId in rewarded do
				if not survivors[userId] then
					return Result.failure("InvalidRequest")
				end
			end
			local amounts: { [number]: number } = {}
			for _, payout in Calculator.survival(context.Value.Options).Payouts do
				amounts[payout.UserId] = payout.Coins
			end
			local payouts: { Settlement.Payout } = {}
			for userId in all do
				local payout = Settlement.empty(userId)
				payout.Coins, payout.Rounds = amounts[userId] or 0, 1
				payout.Survives = if survivors[userId] then 1 else 0
				table.insert(payouts, payout)
			end
			return Settlement.apply(data, engine, {
				Kind = "Survival",
				SourceId = source.SettlementId,
				SnapshotId = context.Value.SnapshotId,
				Payouts = payouts,
			}, ready)
		end)
	end
	service.AwardXP = function(
		_self: Service.Interface,
		transaction: Payloads.EconomyTransaction
	): Result.Result<Payloads.TransactionReceipt>
		if not ready() then
			return Result.failure("NotReady")
		end
		if not Transaction.validate(transaction) then
			return Result.failure("InvalidRequest")
		end
		local coinDelta, xpDelta = transaction.CoinDelta, transaction.XpDelta
		local command: Operations.Command = {
			TransactionId = transaction.TransactionId,
			UserId = transaction.UserId,
			ExpectedRevision = transaction.ExpectedRevision,
			Reason = transaction.Reason,
			Fingerprint = string.format("award|%.17g|%.17g", coinDelta, xpDelta),
		}
		return engine.execute(command, function(profile)
			local coins, xp = profile.Coins + coinDelta, profile.TotalXP + xpDelta
			if coins < 0 then
				return Result.failure("InsufficientFunds")
			end
			if
				not Validation.finite(coins)
				or not Validation.finite(xp)
				or xp < 0
				or coins > Config.MaxInteger
				or xp > Config.MaxInteger
			then
				return Result.failure("InvalidRequest")
			end
			profile.Coins, profile.TotalXP = coins, xp
			return Result.success(true)
		end, ready)
	end
	service.QueryBalance = function(_self: Service.Interface, userId: number): Result.Result<number>
		if not ready() then
			return Result.failure("NotReady")
		end
		local read = data:Read(userId)
		return if read.Ok then Result.success(read.Value.Coins) else Result.failure(read.Code)
	end
	return service
end

return table.freeze(Implementation)
