--!strict
local Types = require(script.Types)
local DeepFreeze = require(script.Parent.Parent.Util.DeepFreeze)
export type ScenarioDefinition = Types.ScenarioDefinition
export type Catalog = {
	Definitions: { ScenarioDefinition },
	ById: { [string]: ScenarioDefinition },
}

--[=[ Exact source weights/counts. Event instances are selected by the scenario director. ]=]
local definitions: { ScenarioDefinition } = {
	require(script.regular),
	require(script.not_regular),
	require(script.weird),
	require(script.big_boss),
	require(script.its_over),
}
table.sort(definitions, function(first: ScenarioDefinition, second: ScenarioDefinition): boolean
	return first.Id < second.Id
end)
local byId: { [string]: ScenarioDefinition } = {}
for _, definition in definitions do
	byId[definition.Id] = definition
end
local catalog: Catalog = { Definitions = definitions, ById = byId }
DeepFreeze.freeze((catalog :: unknown) :: DeepFreeze.DataTable)

return catalog
