--!strict
-- D-21: linear leveling is confirmed;100 XP/level remains provisional in Game.Proposals.
local Validation = require("../../Registry/Validation")
local Limits = require("../../Config/Validation")

export type Progress = {
	Level: number,
	TotalXP: number,
	XpPerLevel: number,
	ProgressXP: number,
	RemainingXP: number,
	ProgressFraction: number,
}

local XpCurve = {}

--[=[ Derives linear level/progress from cumulative XP and an explicitly injected threshold.
	This function does not award XP or select a tuning proposal on the owner's behalf.
]=]
function XpCurve.calculate(totalXP: number, xpPerLevel: number): Progress
	assert(Validation.finite(totalXP) and totalXP >= 0, "TotalXP must be finite and nonnegative")
	assert(Validation.finite(xpPerLevel) and xpPerLevel > 0, "XpPerLevel must be finite and positive")
	local completed = math.floor(totalXP / xpPerLevel)
	assert(
		Validation.integer(completed, 0, Limits.MaxInteger - 1),
		"Derived level exceeds safe integer range"
	)
	local progress = totalXP % xpPerLevel
	return table.freeze({
		Level = completed + 1,
		TotalXP = totalXP,
		XpPerLevel = xpPerLevel,
		ProgressXP = progress,
		RemainingXP = xpPerLevel - progress,
		ProgressFraction = progress / xpPerLevel,
	})
end

return table.freeze(XpCurve)
