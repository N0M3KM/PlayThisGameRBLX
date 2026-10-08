--!strict
local Types = require("./Types")
local DeepFreeze = require("../../Util/DeepFreeze")
local definition: Types.ScenarioDefinition = {
	Id = "regular",
	DisplayName = "Regular",
	Weight = 50,
	DroidMultiplier = 1,
	RewardMultiplier = 1,
	EventMinimum = 0,
	EventMaximum = 1,
	DisasterMinimum = 0,
	DisasterMaximum = 0,
	BossCount = 0,
}

DeepFreeze.freeze((definition :: unknown) :: DeepFreeze.DataTable)

return definition
