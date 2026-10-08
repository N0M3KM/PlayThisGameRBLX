--!strict
local Types = require("./Types")
local DeepFreeze = require("../../Util/DeepFreeze")
local definition: Types.MapDefinition = {
	Id = "the_town",
	DisplayName = "The Town",
	AssetId = "the_town",
	SpawnWeight = 1, -- Provisional equal voting weight.
	SpawnRate = 1.5,
	CoinMultiplier = 1,
	XpMultiplier = 1,
	DroidPool = { "regular", "chaser", "range", "worker", "police" },
}

DeepFreeze.freeze((definition :: unknown) :: DeepFreeze.DataTable)

return definition
