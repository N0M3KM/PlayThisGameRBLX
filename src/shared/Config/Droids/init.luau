--!strict
local Types = require(script.Types)
local Registry = require(script.Parent.Parent.Registry.Registry)
local Validation = require(script.Parent.Parent.Registry.Validation)
local DeepFreeze = require(script.Parent.Parent.Util.DeepFreeze)
local MapCatalog = require(script.Parent.Maps)

export type DroidDefinition = Types.DroidDefinition
export type Catalog = {
	Definitions: { DroidDefinition },
	ById: { [string]: DroidDefinition },
}

local VALID_ABILITIES: { [string]: boolean } = {
	melee = true,
	lunge = true,
	shoot = true,
	throw_paper = true,
	shock_gun = true,
	sit_recover = true,
}

local function validate(definition: DroidDefinition): { string }
	local errors: { string } = {}
	local function issue(field: string, expected: string)
		table.insert(errors, `{field}: expected {expected}`)
	end
	if not Validation.id(definition.Id) then
		issue("Id", "stable snake_case identifier")
	end
	if definition.DisplayName == "" then
		issue("DisplayName", "non-empty source name")
	end
	if definition.AssetId ~= definition.Id then
		issue("AssetId", `matching droid template {definition.Id}`)
	end
	if not Validation.integer(definition.SpawnWeight, 0, 100000) then
		issue("SpawnWeight", "whole nonnegative relative pool weight")
	end
	if not Validation.integer(definition.MaxHP, 1, 1000000000) then
		issue("MaxHP", "positive whole health")
	end
	if not Validation.finite(definition.Melee.Damage) or definition.Melee.Damage <= 0 then
		issue("Melee.Damage", "positive finite damage")
	end
	if
		definition.Melee.CooldownSeconds ~= nil
		and (not Validation.finite(definition.Melee.CooldownSeconds) or definition.Melee.CooldownSeconds <= 0)
	then
		issue("Melee.CooldownSeconds", "positive finite duration or omitted owner TODO")
	end
	if definition.EventOnly and definition.SpawnWeight ~= 0 then
		issue("SpawnWeight", "zero for event-only definitions")
	elseif not definition.EventOnly and definition.SpawnWeight == 0 then
		issue("SpawnWeight", "positive for map-pool definitions")
	end
	if type(definition.EventOnly) ~= "boolean" then
		issue("EventOnly", "boolean event scope")
	end
	if type(definition.BulletImmune) ~= "boolean" then
		issue("BulletImmune", "boolean bullet-immunity trait")
	end
	if not Validation.finite(definition.XPProposal) or definition.XPProposal < 0 then
		issue("XPProposal", "nonnegative finite unapproved proposal")
	end
	if #definition.Abilities == 0 or definition.Abilities[1] ~= "melee" then
		issue("Abilities", "include melee as the first behavior")
	end
	local seenAbilities: { [string]: boolean } = {}
	for _, ability in definition.Abilities do
		if not VALID_ABILITIES[ability] or seenAbilities[ability] then
			issue("Abilities", "known unique lowercase ability IDs")
		end
		seenAbilities[ability] = true
	end
	local seenMaps: { [string]: boolean } = {}
	for _, mapId in definition.Maps do
		if MapCatalog.ById[mapId] == nil then
			issue("Maps", `known map ID from the map catalog, got {mapId}`)
		end
		if seenMaps[mapId] then
			issue("Maps", `unique map IDs, repeated {mapId}`)
		end
		seenMaps[mapId] = true
	end
	if definition.EventOnly and #definition.Maps ~= 0 then
		issue("Maps", "empty for event-only definitions")
	elseif not definition.EventOnly and #definition.Maps == 0 then
		issue("Maps", "at least one eligible map")
	end
	for parameter, value in definition.AbilityParams do
		if parameter == "" or not Validation.finite(value) or value <= 0 then
			issue(`AbilityParams.{parameter}`, "named positive finite tuning")
		end
	end
	for _, todo in definition.TuningTodo do
		if todo == "" then
			issue("TuningTodo", "non-empty owner TODO entries")
		end
	end
	if definition.Melee.CooldownSeconds == nil then
		if not table.find(definition.TuningTodo, "Melee cooldown") then
			issue("TuningTodo", "include Melee cooldown when the source omits it")
		end
	end
	return errors
end

local function idOf(definition: DroidDefinition): string
	return definition.Id
end
local function freeze(definition: DroidDefinition)
	DeepFreeze.freeze((definition :: unknown) :: DeepFreeze.DataTable)
end
local registry = Registry.new(idOf, validate, freeze)

--[=[ Discover each sibling definition; Types is the only support module. ]=]
for _, child in script:GetChildren() do
	if child:IsA("ModuleScript") and child.Name ~= "Types" then
		local definition = require(child) :: DroidDefinition
		registry:add(definition)
	end
end
registry:seal()

local definitions = registry:all()
local byId: { [string]: DroidDefinition } = {}
for _, definition in definitions do
	byId[definition.Id] = definition
end
local catalog: Catalog = { Definitions = definitions, ById = byId }
DeepFreeze.freeze((catalog :: unknown) :: DeepFreeze.DataTable)

return catalog
