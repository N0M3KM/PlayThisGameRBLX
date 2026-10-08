--!strict
local Types = require("./Types")
local DeepFreeze = require("../../Util/DeepFreeze")

local definition: Types.DroidDefinition = {
	Id = "regular",
	DisplayName = "Regular Droid",
	AssetId = "regular",
	SpawnWeight = 90,
	MaxHP = 100,
	Melee = { Damage = 5, CooldownSeconds = 1 },
	Abilities = { "melee" },
	Maps = { "baseplate", "classic_house", "the_town" },
	EventOnly = false,
	BulletImmune = false,
	XPProposal = 20,
	AbilityParams = {},
	TuningTodo = { "XPProposal is provisional and needs owner approval" },
}

DeepFreeze.freeze((definition :: unknown) :: DeepFreeze.DataTable)
return definition
