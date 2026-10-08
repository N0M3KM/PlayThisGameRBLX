--!strict
local Types = require("./Types")
local DeepFreeze = require("../../Util/DeepFreeze")

local definition: Types.DroidDefinition = {
	Id = "police",
	DisplayName = "Police Droid",
	AssetId = "police",
	SpawnWeight = 15,
	MaxHP = 120,
	Melee = { Damage = 15, CooldownSeconds = 1 },
	Abilities = { "melee", "shock_gun" },
	Maps = { "the_town" },
	EventOnly = false,
	BulletImmune = false,
	XPProposal = 24,
	AbilityParams = { ShockGunCooldownSeconds = 30, ShockGunStunSeconds = 5 },
	TuningTodo = {
		"Shock gun range",
		"XPProposal is provisional and needs owner approval",
	},
}

DeepFreeze.freeze((definition :: unknown) :: DeepFreeze.DataTable)
return definition
