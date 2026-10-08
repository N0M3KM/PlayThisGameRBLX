--!strict
local DroidAI = require("@game/ReplicatedStorage/Shared/Contracts/DroidAI")
local FactionTargeting = require("../../Services/Droids/FactionTargeting")

local StructureTargets = {}

--[=[ A frame is the entire authority snapshot: removed structures never remain cached targets. ]=]
function StructureTargets.valid(agent: DroidAI.Agent, target: DroidAI.Target): boolean
	return target.Hp > 0
		and target.Entity.RoundId == agent.Entity.RoundId
		and target.Entity.Id ~= agent.Entity.Id
		and FactionTargeting.canTarget(agent.Faction, target.Faction)
end

return table.freeze(StructureTargets)
