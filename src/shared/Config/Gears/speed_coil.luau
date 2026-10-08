--!strict
local Types = require("./Types")
local DeepFreeze = require("../../Util/DeepFreeze")
local definition: Types.GearDefinition = {
	Id = "speed_coil",
	DisplayName = "Speed Coil",
	AssetId = "speed_coil",
	Category = "Booster",
	Strategy = "Booster",
	Acquisition = "Shop",
	Price = 3500,
	Effects = { "WalkSpeedMultiplier" },
	WalkSpeedMultiplier = 2,
}
DeepFreeze.freeze((definition :: unknown) :: DeepFreeze.DataTable)
return definition
