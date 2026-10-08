--!strict
-- Prepared only: deterministic reward regressions, not persistence/Studio evidence.
local RewardCalculator = require("../../../src/shared/Util/Economy/RewardCalculator")
local XpCurve = require("../../../src/shared/Util/Economy/XpCurve")

local function near(actual: number, expected: number)
	assert(
		math.abs(actual - expected) <= 1e-9 * math.max(1, math.abs(expected)),
		`Expected {expected}, got {actual}`
	)
end

local function rejected(callback: () -> ())
	local ok = pcall(callback)
	assert(not ok, "Invalid reward input must be rejected")
end

local function kill(): RewardCalculator.KillOptions
	return {
		BaseXP = 20,
		MaxHP = 100,
		KillerUserId = 10,
		Contributions = { { UserId = 10, Damage = 59.78 }, { UserId = 20, Damage = 40.22 } },
		MapMultiplier = 1,
		ScenarioMultiplier = 1,
	}
end

do
	local options = kill()
	local payout = RewardCalculator.nonBoss(options).Payouts[1]
	assert(payout.UserId == 10 and payout.Share == 0.59, "Only the killer gets its truncated share")
	near(payout.XP, 11.8)
	near(payout.Coins, 5.9)
	options.Contributions = { { UserId = 10, Damage = 1 }, { UserId = 20, Damage = 0 } }
	near(RewardCalculator.nonBoss(options).Payouts[1].XP, 20)
	options.KillerUserId = 30
	assert(#RewardCalculator.nonBoss(options).Payouts == 0, "An uncredited killer gets nothing")
	options.KillerUserId = nil
	assert(#RewardCalculator.nonBoss(options).Payouts == 0, "Environmental deaths do not invent a killer")
end

do
	local options = kill()
	options.Contributions = { { UserId = 10, Damage = 100 } }
	options.MapMultiplier = 1.25
	options.XpBoosts = { [10] = 2 }
	options.CoinBoosts = { [10] = 3 }
	local payout = RewardCalculator.nonBoss(options).Payouts[1]
	near(payout.XP, 50)
	near(payout.Coins, 75)
	near(RewardCalculator.combine(1, 1), 1)
	near(RewardCalculator.combine(1.25, 1.75), 2)
end

do
	local options = kill()
	options.BaseXP = 100
	options.MaxHP = 5000
	options.ScenarioMultiplier = 1.75
	options.Contributions = { { UserId = 20, Damage = 2500 }, { UserId = 10, Damage = 2500 } }
	local calculation = RewardCalculator.boss(options)
	near(calculation.PoolXP, 175)
	assert(calculation.Payouts[1].UserId == 10, "Boss allocation order must be deterministic")
	near(calculation.Payouts[1].XP, 87.5)
	near(calculation.Payouts[2].XP, 87.5)
	options.ScenarioMultiplier = 3
	options.Contributions = {
		{ UserId = 30, Damage = 1 },
		{ UserId = 10, Damage = 1 },
		{ UserId = 20, Damage = 1 },
	}
	calculation = RewardCalculator.boss(options)
	near(calculation.PoolXP, 300)
	near(calculation.Payouts[1].Share, 1 / 3)
	near(calculation.Payouts[1].XP + calculation.Payouts[2].XP + calculation.Payouts[3].XP, 300)
	options.XpBoosts = { [10] = 2 }
	options.CoinBoosts = { [10] = 3 }
	calculation = RewardCalculator.boss(options)
	near(calculation.Payouts[1].XP, 200)
	near(calculation.Payouts[1].Coins, 300)
	options.Contributions = {}
	assert(#RewardCalculator.boss(options).Payouts == 0, "Empty boss ledger must not divide by zero")
end

do
	local options = kill()
	options.Quantize = function(amount, _currency)
		return math.floor(amount)
	end
	local payout = RewardCalculator.nonBoss(options).Payouts[1]
	near(payout.RawXP, 11.8)
	near(payout.RawCoins, 5.9)
	assert(payout.XP == 11 and payout.Coins == 5, "Coins derive before XP quantization")
	local survival = RewardCalculator.survival({
		BaseCoins = 100,
		UserIds = { 20, 10 },
		MapMultiplier = 1.5,
		ScenarioMultiplier = 1.2,
		CoinBoosts = { [10] = 2 },
		Quantize = function(amount, currency)
			return if currency == "XP" then 1 else amount
		end,
	})
	assert(survival.Payouts[1].UserId == 10 and survival.Payouts[1].XP == 0, "Survival cannot grant XP")
	near(survival.Payouts[1].Coins, 340)
	near(survival.Payouts[2].Coins, 170)
end

do
	for _, total in { 0, 99.5, 100, 120, 175, 200 } do
		local progress = XpCurve.calculate(total, 100)
		assert(progress.Level == 1 + math.floor(total / 100), "Linear threshold must derive the level")
		near(progress.ProgressXP, total % 100)
		near(progress.ProgressXP + progress.RemainingXP, 100)
	end
	assert(XpCurve.calculate(100, 50).Level == 3, "Threshold must be injected")
end

do
	for _, value in { -1, math.huge, -math.huge, 0 / 0 } do
		rejected(function()
			local options = kill()
			options.BaseXP = value
			RewardCalculator.nonBoss(options)
		end)
		rejected(function()
			XpCurve.calculate(value, 100)
		end)
	end
	for _, threshold in { 0, -1, math.huge, 0 / 0 } do
		rejected(function()
			XpCurve.calculate(100, threshold)
		end)
	end
	for _, contributions in
		{
			{ { UserId = 10, Damage = 1 }, { UserId = 10, Damage = 1 } },
			{ { UserId = 0, Damage = 1 } },
			{ { UserId = 10, Damage = -1 } },
			{ { UserId = 10, Damage = 101 } },
			{ { UserId = 10, Damage = math.huge } },
		}
	do
		rejected(function()
			local options = kill()
			options.Contributions = contributions
			RewardCalculator.boss(options)
		end)
	end
	rejected(function()
		local options = kill()
		options.Quantize = function(_amount, _currency)
			return -1
		end
		RewardCalculator.nonBoss(options)
	end)
	rejected(function()
		RewardCalculator.survival({
			BaseCoins = 100,
			UserIds = { 10, 10 },
			MapMultiplier = 1,
			ScenarioMultiplier = 1,
		})
	end)
end

return 6
