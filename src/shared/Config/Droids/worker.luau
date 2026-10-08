--!strict
local Types = require("./Types")
local DeepFreeze = require("../../Util/DeepFreeze")

local definition: Types.DroidDefinition = {
	Id = "worker",
	DisplayName = "Worker Droid",
	AssetId = "worker",
	SpawnWeight = 55,
	MaxHP = 150,
	Melee = { Damage = 10, CooldownSeconds = 2 },
	Abilities = { "melee", "throw_paper" },
	Maps = { "the_town" },
	EventOnly = false,
	BulletImmune = false,
	XPProposal = 30,
	AbilityParams = {
		ThrowPaperDamage = 20,
		ThrowPaperRange = 30,
		ThrowPaperCooldownSeconds = 15,
	},
	TuningTodo = {
		"Throw paper projectile speed",
		"XPProposal is provisional and needs owner approval",
	},
}

DeepFreeze.freeze((definition :: unknown) :: DeepFreeze.DataTable)
return definition
