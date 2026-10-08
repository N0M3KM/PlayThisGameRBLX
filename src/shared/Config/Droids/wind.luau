--!strict
local Types = require("./Types")
local DeepFreeze = require("../../Util/DeepFreeze")

local definition: Types.DroidDefinition = {
	Id = "wind",
	DisplayName = "Wind Droid",
	AssetId = "wind",
	SpawnWeight = 0,
	MaxHP = 100,
	Melee = { Damage = 10 },
	Abilities = { "melee" },
	Maps = {},
	EventOnly = true,
	BulletImmune = true,
	XPProposal = 20,
	AbilityParams = {},
	TuningTodo = {
		"Melee cooldown",
		"XPProposal is provisional and needs owner approval",
	},
}

DeepFreeze.freeze((definition :: unknown) :: DeepFreeze.DataTable)
return definition
