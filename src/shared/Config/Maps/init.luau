--!strict
local Types = require(script.Types)
local DeepFreeze = require(script.Parent.Parent.Util.DeepFreeze)
export type MapDefinition = Types.MapDefinition
export type Catalog = {
	Definitions: { MapDefinition },
	ById: { [string]: MapDefinition },
}

--[=[ Source map rates/rewards; equal SpawnWeight is a provisional voting fixture. ]=]
local definitions: { MapDefinition } = {
	require(script.baseplate),
	require(script.classic_house),
	require(script.the_town),
}
table.sort(definitions, function(first: MapDefinition, second: MapDefinition): boolean
	return first.Id < second.Id
end)
local byId: { [string]: MapDefinition } = {}
for _, definition in definitions do
	assert(not byId[definition.Id], `Duplicate map definition {definition.Id}`)
	assert(
		definition.SpawnWeight > 0 and definition.SpawnWeight < math.huge,
		`Invalid map weight {definition.Id}`
	)
	byId[definition.Id] = definition
end
local catalog: Catalog = { Definitions = definitions, ById = byId }
DeepFreeze.freeze((catalog :: unknown) :: DeepFreeze.DataTable)

return catalog
