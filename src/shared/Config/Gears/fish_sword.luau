--!strict
local Types = require("./Types")
local DeepFreeze = require("../../Util/DeepFreeze")
local definition: Types.GearDefinition = {
	Id = "fish_sword",
	DisplayName = "Fish Sword",
	AssetId = "fish_sword",
	Category = "Melee",
	Strategy = "Melee",
	Acquisition = "Shop",
	Price = 700,
	Damage = 15,
	Effects = { "KnockbackEveryHit" },
}
DeepFreeze.freeze((definition :: unknown) :: DeepFreeze.DataTable)
return definition
