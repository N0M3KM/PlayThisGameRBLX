--!strict
local Types = require("./Types")
local DeepFreeze = require("../../Util/DeepFreeze")
local definition: Types.GearDefinition = {
	Id = "crystal_laser_cannon",
	DisplayName = "Crystal Laser Cannon",
	AssetId = "crystal_laser_cannon",
	Category = "Gun",
	Strategy = "Gun",
	Acquisition = "Wheel",
	Damage = 10,
	LoadedAmmo = 50,
	ReserveAmmo = 150,
}
DeepFreeze.freeze((definition :: unknown) :: DeepFreeze.DataTable)
return definition
