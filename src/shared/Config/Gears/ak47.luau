--!strict
local Types = require("./Types")
local DeepFreeze = require("../../Util/DeepFreeze")
local definition: Types.GearDefinition = {
	Id = "ak47",
	DisplayName = "AK47",
	AssetId = "ak47",
	Category = "Gun",
	Strategy = "Gun",
	Acquisition = "Shop",
	Price = 7500,
	Damage = 4,
	LoadedAmmo = 30,
	ReserveAmmo = 60,
}
DeepFreeze.freeze((definition :: unknown) :: DeepFreeze.DataTable)
return definition
