--!strict
local Types = require("./Types")
local DeepFreeze = require("../../Util/DeepFreeze")
local definition: Types.ScenarioDefinition = {
	Id = "its_over",
	DisplayName = "It's Over",
	Weight = 1,
	DroidMultiplier = 1.8,
	RewardMultiplier = 3,
	EventMinimum = 0,
	EventMaximum = 0,
	DisasterMinimum = 2,
	DisasterMaximum = 3,
	BossCount = 2,
}

DeepFreeze.freeze((definition :: unknown) :: DeepFreeze.DataTable)

return definition
