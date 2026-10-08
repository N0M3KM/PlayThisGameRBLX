--!strict
local Types = require("./Types")
local DeepFreeze = require("../../Util/DeepFreeze")
local definition: Types.GearDefinition = {
	Id = "hunter_rifle",
	DisplayName = "Hunter Rifle",
	AssetId = "hunter_rifle",
	Category = "Gun",
	Strategy = "Gun",
	Acquisition = "Shop",
	Price = 1500,
	Damage = 40,
	LoadedAmmo = 1,
	ReserveAmmo = 5,
}
DeepFreeze.freeze((definition :: unknown) :: DeepFreeze.DataTable)
return definition
