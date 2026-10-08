--!strict
local Types = require("./Types")
local DeepFreeze = require("../../Util/DeepFreeze")
local definition: Types.GearDefinition = {
	Id = "push",
	DisplayName = "Push",
	AssetId = "push",
	Category = "Melee",
	Strategy = "Melee",
	Acquisition = "Shop",
	Price = 100,
	Damage = 5,
	Effects = { "MinorKnockback" },
}
DeepFreeze.freeze((definition :: unknown) :: DeepFreeze.DataTable)
return definition
