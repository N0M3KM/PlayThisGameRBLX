--!strict
local Types = require("./Types")
local DeepFreeze = require("../../Util/DeepFreeze")
local definition: Types.ScenarioDefinition = {
	Id = "weird",
	DisplayName = "Weird",
	Weight = 10,
	DroidMultiplier = 1.2,
	RewardMultiplier = 1.5,
	EventMinimum = 2,
	EventMaximum = 3,
	DisasterMinimum = 0,
	DisasterMaximum = 0,
	BossCount = 0,
}

DeepFreeze.freeze((definition :: unknown) :: DeepFreeze.DataTable)

return definition
