--!strict
local Payloads = require("../../Contracts/Payloads")
local Result = require("../../Contracts/Result")
local StatModifier = {}
export type Stats = { [string]: number }
export type Policy = { WalkSpeedStat: string, WalkSpeedCap: number }

function StatModifier.finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

function StatModifier.valid(modifier: Payloads.StatModifier): boolean
	return type(modifier.SourceId) == "string"
		and #modifier.SourceId > 0
		and type(modifier.Stat) == "string"
		and #modifier.Stat > 0
		and (modifier.Mode == "Add" or modifier.Mode == "Multiply")
		and type(modifier.Value) == "number"
		and StatModifier.finite(modifier.Value)
		and (modifier.Mode ~= "Multiply" or modifier.Value >= 0)
end

--[=[ Non-speed layers use (base + summed additions) * multiplied factors.
	Speed uses the strongest boost and strongest slowdown, each once, then caps.
	A zero factor therefore overrides every speed boost. Policy is injected tuning.
]=]
function StatModifier.resolve(
	base: Stats,
	modifiers: { Payloads.StatModifier },
	policy: Policy
): Result.Result<Stats>
	if not StatModifier.finite(policy.WalkSpeedCap) or policy.WalkSpeedCap < 0 then
		return Result.failure("InvalidRequest")
	end
	for _, modifier in modifiers do
		if not StatModifier.valid(modifier) or base[modifier.Stat] == nil then
			return Result.failure("InvalidRequest")
		end
	end
	local result: Stats = {}
	for stat, value in base do
		if not StatModifier.finite(value) then
			return Result.failure("InvalidRequest")
		end
		local add, factor, boost, slow = 0, 1, 1, 1
		for _, modifier in modifiers do
			if modifier.Stat == stat then
				if modifier.Mode == "Add" then
					add += modifier.Value
				elseif stat == policy.WalkSpeedStat then
					boost = math.max(boost, modifier.Value)
					slow = math.min(slow, modifier.Value)
				else
					factor *= modifier.Value
				end
			end
		end
		local resolved = (value + add) * (if stat == policy.WalkSpeedStat then boost * slow else factor)
		if not StatModifier.finite(resolved) then
			return Result.failure("LimitReached")
		end
		result[stat] = if stat == policy.WalkSpeedStat
			then math.clamp(resolved, 0, policy.WalkSpeedCap)
			else resolved
	end
	return Result.success(table.freeze(result))
end

return table.freeze(StatModifier)
