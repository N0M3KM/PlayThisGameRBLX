--!strict
local Types = require("./Types")
local DeepFreeze = require("../../Util/DeepFreeze")
local definition: Types.GearDefinition = {
	Id = "classic_sword",
	DisplayName = "Classic Roblox Sword",
	AssetId = "classic_sword",
	Category = "Melee",
	Strategy = "Melee",
	Acquisition = "Shop",
	Price = 250,
	Damage = 15,
	Effects = { "BasicMelee" },
}
DeepFreeze.freeze((definition :: unknown) :: DeepFreeze.DataTable)
return definition
