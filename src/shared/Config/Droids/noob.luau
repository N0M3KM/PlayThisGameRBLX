--!strict
local Types = require("./Types")
local DeepFreeze = require("../../Util/DeepFreeze")

local definition: Types.DroidDefinition = {
	Id = "noob",
	DisplayName = "Noob Droid",
	AssetId = "noob",
	SpawnWeight = 75,
	MaxHP = 300,
	Melee = { Damage = 5, CooldownSeconds = 1 },
	Abilities = { "melee" },
	Maps = { "classic_house" },
	EventOnly = false,
	BulletImmune = false,
	XPProposal = 60,
	AbilityParams = {},
	TuningTodo = { "XPProposal is provisional and needs owner approval" },
}

DeepFreeze.freeze((definition :: unknown) :: DeepFreeze.DataTable)
return definition
