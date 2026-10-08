--!strict
local DroidAI = require("@game/ReplicatedStorage/Shared/Contracts/DroidAI")
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local StructureTargets = require("./StructureTargets")

local TargetScoring = {}

function TargetScoring.key(entity: Payloads.EntityRef): string
	return tostring(entity.RoundId) .. ":" .. tostring(entity.Generation) .. ":" .. entity.Id
end

function TargetScoring.distanceSquared(a: Payloads.Point, b: Payloads.Point): number
	local x, y, z = a.X - b.X, a.Y - b.Y, a.Z - b.Z
	return x * x + y * y + z * z
end

--[=[ Stable ties and squared distances make scoring deterministic across worker batches. ]=]
function TargetScoring.choose(
	agent: DroidAI.Agent,
	targets: { DroidAI.Target },
	policy: DroidAI.Policy
): DroidAI.Target?
	local winner: DroidAI.Target? = nil
	local best = -math.huge
	local bestKey = ""
	local lastAttacker = if agent.LastAttacker then TargetScoring.key(agent.LastAttacker) else nil
	local rangeSquared = policy.AcquireRange * policy.AcquireRange
	for _, target in targets do
		if StructureTargets.valid(agent, target) then
			local distance = TargetScoring.distanceSquared(agent.Position, target.Position)
			if distance == distance and distance <= rangeSquared then
				local id = TargetScoring.key(target.Entity)
				local score = -distance * policy.DistanceWeight
				if id == lastAttacker then
					score += policy.LastAttackerBonus
				end
				if target.Structure then
					score += policy.StructureBonus
				end
				if score > best or (score == best and (winner == nil or id < bestKey)) then
					winner, best, bestKey = target, score, id
				end
			end
		end
	end
	return winner
end

return table.freeze(TargetScoring)
