--!strict
-- Pure D-05/D-21/R-02/R-04 reward facts; callers own settlement IDs and durable writes.
local Validation = require("../../Registry/Validation")
local Limits = require("../../Config/Validation")

export type CombineMode = "SumBonus" | "SumRaw" | "Product"
export type Quantizer = (amount: number, currency: "XP" | "Coins") -> number
export type Contribution = { UserId: number, Damage: number }
export type Boosts = { [number]: number }
export type Factors = {
	MapMultiplier: number,
	ScenarioMultiplier: number,
	CombineMode: CombineMode?,
	XpBoosts: Boosts?,
	CoinBoosts: Boosts?,
	Quantize: Quantizer?,
}
export type KillOptions = Factors & {
	BaseXP: number,
	MaxHP: number,
	KillerUserId: number?,
	Contributions: { Contribution },
}
export type SurvivalOptions = Factors & { BaseCoins: number, UserIds: { number } }
export type Payout = {
	UserId: number,
	Damage: number,
	Share: number,
	BaseXP: number,
	BaseCoins: number,
	RawXP: number,
	RawCoins: number,
	XP: number,
	Coins: number,
}
export type Calculation = {
	PoolXP: number,
	PoolCoins: number,
	TotalCreditedDamage: number,
	Payouts: { Payout },
}

local RewardCalculator = {}

local function nonnegative(value: number, label: string): number
	assert(Validation.finite(value) and value >= 0, label .. " must be finite and nonnegative")
	return value
end

local function userId(value: number)
	assert(Validation.playerId(value, Limits.MaxInteger), "UserId must be a nonzero safe integer")
end

local function array<T>(values: { T })
	assert(type(values) == "table", "Expected an array")
	local count = 0
	for key in values do
		assert(type(key) == "number" and key > 0 and key % 1 == 0, "Invalid array key")
		count += 1
	end
	for index = 1, count do
		assert(values[index] ~= nil, "Array must not contain gaps")
	end
end

local function validateBoosts(boosts: Boosts?)
	if boosts == nil then
		return
	end
	assert(type(boosts) == "table", "Boosts must be a dictionary")
	for id, multiplier in boosts do
		userId(id)
		nonnegative(multiplier, "Boost multiplier")
	end
end

local function validateFactors(options: Factors)
	validateBoosts(options.XpBoosts)
	validateBoosts(options.CoinBoosts)
	assert(options.Quantize == nil or type(options.Quantize) == "function", "Invalid quantizer")
end

--[=[ Combines injected catalog factors. SumBonus preserves a neutral multiplier of one. ]=]
function RewardCalculator.combine(map: number, scenario: number, mode: CombineMode?): number
	nonnegative(map, "MapMultiplier")
	nonnegative(scenario, "ScenarioMultiplier")
	local result: number
	if mode == nil or mode == "SumBonus" then
		result = 1 + (map - 1) + (scenario - 1)
	elseif mode == "SumRaw" then
		result = map + scenario
	else
		assert(mode == "Product", "Unknown multiplier strategy")
		result = map * scenario
	end
	return nonnegative(result, "Combined multiplier")
end

local function ledger(options: KillOptions): ({ Contribution }, number)
	nonnegative(options.MaxHP, "MaxHP")
	assert(options.MaxHP > 0, "MaxHP must be positive")
	array(options.Contributions)
	local seen: { [number]: boolean } = {}
	local contributions: { Contribution } = {}
	for _, entry in options.Contributions do
		assert(type(entry) == "table", "Contribution must be a table")
		userId(entry.UserId)
		assert(not seen[entry.UserId], "Duplicate contributor UserId")
		seen[entry.UserId] = true
		nonnegative(entry.Damage, "Credited damage")
		if entry.Damage > 0 then
			table.insert(contributions, { UserId = entry.UserId, Damage = entry.Damage })
		end
	end
	table.sort(contributions, function(left: Contribution, right: Contribution): boolean
		return left.UserId < right.UserId
	end)
	local total = 0
	for _, entry in contributions do
		total = nonnegative(total + entry.Damage, "Total credited damage")
	end
	assert(total <= options.MaxHP, "Credited damage exceeds MaxHP; exclude overkill")
	return contributions, total
end

local function boost(boosts: Boosts?, id: number): number
	if boosts == nil then
		return 1
	end
	local multiplier = boosts[id]
	return if multiplier == nil then 1 else multiplier
end

local function quantize(options: Factors, amount: number, currency: "XP" | "Coins"): number
	if amount == 0 then
		return 0
	end
	local callback = options.Quantize
	return if callback == nil then amount else nonnegative(callback(amount, currency), "Quantized reward")
end

local function payout(
	options: Factors,
	id: number,
	damage: number,
	share: number,
	xp: number,
	coins: number
): Payout
	local rawXP = nonnegative(xp * boost(options.XpBoosts, id), "Boosted XP")
	-- Literal R-04: coins inherit unquantized XP factors and XP boost before coin boost.
	local rawCoins = nonnegative((coins + rawXP / 2) * boost(options.CoinBoosts, id), "Boosted coins")
	return table.freeze({
		UserId = id,
		Damage = damage,
		Share = share,
		BaseXP = xp,
		BaseCoins = coins + xp / 2,
		RawXP = rawXP,
		RawCoins = rawCoins,
		XP = quantize(options, rawXP, "XP"),
		Coins = quantize(options, rawCoins, "Coins"),
	})
end

local function result(poolXP: number, poolCoins: number, total: number, payouts: { Payout }): Calculation
	return table.freeze({
		PoolXP = poolXP,
		PoolCoins = poolCoins,
		TotalCreditedDamage = total,
		Payouts = table.freeze(payouts),
	})
end

local function killPool(options: KillOptions): number
	validateFactors(options)
	if options.KillerUserId ~= nil then
		userId(options.KillerUserId)
	end
	return nonnegative(
		nonnegative(options.BaseXP, "BaseXP")
			* RewardCalculator.combine(options.MapMultiplier, options.ScenarioMultiplier, options.CombineMode),
		"Reward pool XP"
	)
end

--[=[ Rewards only a positive-damage killer. Assistants remain in the caller's ledger.
	The ordinary ratio truncates to two decimals; a sole positive contributor receives one.
	An absent/uncredited killer receives nothing. The function does not deduplicate settlements.
]=]
function RewardCalculator.nonBoss(options: KillOptions): Calculation
	local poolXP = killPool(options)
	local contributions, total = ledger(options)
	local killer = options.KillerUserId
	local payouts: { Payout } = {}
	if killer ~= nil then
		userId(killer)
		for _, entry in contributions do
			if entry.UserId == killer then
				local ratio = if #contributions == 1
					then 1
					else math.floor(entry.Damage / options.MaxHP * 100) / 100
				table.insert(payouts, payout(options, killer, entry.Damage, ratio, poolXP * ratio, 0))
				break
			end
		end
	end
	return result(poolXP, poolXP / 2, total, payouts)
end

--[=[ Shares one base pool across positive actual-damage contributors in UserId order.
	Shares retain full precision; personal boosts and optional explicit quantization follow.
	Zero contribution returns no payouts. Offline identities remain eligible; the durable
	settlement layer must defer unavailable profiles rather than open competing sessions.
]=]
function RewardCalculator.boss(options: KillOptions): Calculation
	local poolXP = killPool(options)
	local contributions, total = ledger(options)
	local payouts: { Payout } = {}
	for _, entry in contributions do
		local share = entry.Damage / total
		table.insert(payouts, payout(options, entry.UserId, entry.Damage, share, poolXP * share, 0))
	end
	return result(poolXP, poolXP / 2, total, payouts)
end

--[=[ Produces coin-only survival facts for the injected eligible survivor snapshot.
	The catalog supplies BaseCoins (brief100); no survival XP or eligibility is invented here.
]=]
function RewardCalculator.survival(options: SurvivalOptions): Calculation
	validateFactors(options)
	local baseCoins = nonnegative(
		nonnegative(options.BaseCoins, "BaseCoins")
			* RewardCalculator.combine(options.MapMultiplier, options.ScenarioMultiplier, options.CombineMode),
		"Survival coins"
	)
	array(options.UserIds)
	local seen: { [number]: boolean } = {}
	local ids: { number } = {}
	for _, id in options.UserIds do
		userId(id)
		assert(not seen[id], "Duplicate survivor UserId")
		seen[id] = true
		table.insert(ids, id)
	end
	table.sort(ids)
	local payouts: { Payout } = {}
	for _, id in ids do
		table.insert(payouts, payout(options, id, 0, 1, 0, baseCoins))
	end
	return result(0, nonnegative(baseCoins * #ids, "Survival pool coins"), 0, payouts)
end

return table.freeze(RewardCalculator)
