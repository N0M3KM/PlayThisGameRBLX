--!strict
local Types = require("./Types")
local DeepFreeze = require("../../Util/DeepFreeze")
local definition: Types.MapDefinition = {
	Id = "classic_house",
	DisplayName = "Classic House",
	AssetId = "classic_house",
	SpawnWeight = 1, -- Provisional equal voting weight.
	SpawnRate = 1,
	CoinMultiplier = 1,
	XpMultiplier = 1,
	DroidPool = { "regular", "chaser", "range", "noob" },
}

DeepFreeze.freeze((definition :: unknown) :: DeepFreeze.DataTable)

return definition
