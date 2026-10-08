--!strict
local Types = require("./Types")
local DeepFreeze = require("../../Util/DeepFreeze")

local definition: Types.DroidDefinition = {
	Id = "chaser",
	DisplayName = "Chaser Droid",
	AssetId = "chaser",
	SpawnWeight = 70,
	MaxHP = 100,
	Melee = { Damage = 5, CooldownSeconds = 1 },
	Abilities = { "melee", "lunge", "sit_recover" },
	Maps = { "baseplate", "classic_house", "the_town" },
	EventOnly = false,
	BulletImmune = false,
	XPProposal = 20,
	AbilityParams = { LungeRange = 20, LungeCooldownSeconds = 30, SitRecoverSeconds = 3 },
	TuningTodo = {
		"Lunge stun duration",
		"Lunge ragdoll duration",
		"XPProposal is provisional and needs owner approval",
	},
}

DeepFreeze.freeze((definition :: unknown) :: DeepFreeze.DataTable)
return definition
