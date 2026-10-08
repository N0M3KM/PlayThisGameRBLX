--!strict
local Types = require("./Types")
local DeepFreeze = require("../../Util/DeepFreeze")
local definition: Types.GearDefinition = {
	Id = "lightsaber",
	DisplayName = "Lightsaber",
	AssetId = "lightsaber",
	Category = "Melee",
	Strategy = "Melee",
	Acquisition = "Wheel",
	Damage = 50,
	Ability = {
		Id = "summon_ally",
		InputAction = "E",
		CooldownSeconds = 40,
	},
}
DeepFreeze.freeze((definition :: unknown) :: DeepFreeze.DataTable)
return definition
