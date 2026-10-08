--!strict
local States = require("@game/ReplicatedStorage/Shared/Contracts/States")

local FactionTargeting = {}

--[=[ Structures use their owner's faction; allies and players can only attack hostiles. ]=]
function FactionTargeting.canTarget(source: States.Faction, target: States.Faction): boolean
	if source == "Hostile" then
		return target == "Player" or target == "Allied"
	end
	return (source == "Allied" or source == "Player") and target == "Hostile"
end

return table.freeze(FactionTargeting)
