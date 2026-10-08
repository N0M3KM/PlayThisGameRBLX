--!strict
local Types = require("./Types")
local DeepFreeze = require("../../Util/DeepFreeze")
local definition: Types.GearDefinition = {
	Id = "green_balloon",
	DisplayName = "Green Balloon",
	AssetId = "green_balloon",
	Category = "Booster",
	Strategy = "Booster",
	Acquisition = "Shop",
	Price = 5000,
	Effects = { "HighJump" },
	JumpMultiplierTodo = "TODO(owner): D-26/R-source",
}
DeepFreeze.freeze((definition :: unknown) :: DeepFreeze.DataTable)
return definition
