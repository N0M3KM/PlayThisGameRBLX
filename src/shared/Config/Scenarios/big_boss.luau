--!strict
local Types = require("./Types")
local DeepFreeze = require("../../Util/DeepFreeze")
local definition: Types.ScenarioDefinition = {
	Id = "big_boss",
	DisplayName = "Big Boss Droid",
	Weight = 4,
	DroidMultiplier = 1.5,
	RewardMultiplier = 1.75,
	EventMinimum = 0,
	EventMaximum = 0,
	DisasterMinimum = 0,
	DisasterMaximum = 0,
	BossCount = 1,
}

DeepFreeze.freeze((definition :: unknown) :: DeepFreeze.DataTable)

return definition
