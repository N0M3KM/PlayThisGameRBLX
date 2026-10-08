--!strict
local Types = require("./Types")
local DeepFreeze = require("../../Util/DeepFreeze")

local definition: Types.DroidDefinition = {
	Id = "range",
	DisplayName = "Range Droid",
	AssetId = "range",
	SpawnWeight = 25,
	MaxHP = 50,
	Melee = { Damage = 2, CooldownSeconds = 0.2 },
	Abilities = { "melee", "shoot" },
	Maps = { "baseplate", "classic_house", "the_town" },
	EventOnly = false,
	BulletImmune = false,
	XPProposal = 10,
	AbilityParams = { ShootRange = 20 },
	TuningTodo = {
		"Shoot projectile damage",
		"Shoot cadence",
		"Shoot projectile speed",
		"XPProposal is provisional and needs owner approval",
	},
}

DeepFreeze.freeze((definition :: unknown) :: DeepFreeze.DataTable)
return definition
