--!strict
local Types = require("./Types")
local DeepFreeze = require("../../Util/DeepFreeze")
local definition: Types.ScenarioDefinition = {
	Id = "not_regular",
	DisplayName = "Not Regular",
	Weight = 35,
	DroidMultiplier = 1.2,
	RewardMultiplier = 1.2,
	EventMinimum = 1,
	EventMaximum = 2,
	DisasterMinimum = 0,
	DisasterMaximum = 0,
	BossCount = 0,
}

DeepFreeze.freeze((definition :: unknown) :: DeepFreeze.DataTable)

return definition
