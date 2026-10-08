--!strict
local Types = require("./Types")
local DeepFreeze = require("../../Util/DeepFreeze")
local definition: Types.MapDefinition = {
	Id = "baseplate",
	DisplayName = "Baseplate",
	AssetId = "baseplate",
	SpawnWeight = 1, -- Provisional equal voting weight; not a droid spawn multiplier.
	SpawnRate = 1,
	CoinMultiplier = 1.5,
	XpMultiplier = 1.25,
	DroidPool = { "regular", "chaser", "range" },
}

DeepFreeze.freeze((definition :: unknown) :: DeepFreeze.DataTable)

return definition
