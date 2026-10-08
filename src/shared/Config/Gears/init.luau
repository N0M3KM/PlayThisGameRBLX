--!strict
local Types = require(script.Types)
local Registry = require(script.Parent.Parent.Registry.Registry)
local Validation = require(script.Parent.Parent.Registry.Validation)
local DeepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

export type GearDefinition = Types.GearDefinition
export type Catalog = {
	Definitions: { GearDefinition },
	ById: { [string]: GearDefinition },
}

local function validate(definition: GearDefinition): { string }
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
		issue("AssetId", `matching asset folder {definition.Id}`)
	end
	if
		definition.Category ~= "Melee"
		and definition.Category ~= "Gun"
		and definition.Category ~= "Booster"
	then
		issue("Category", "Melee, Gun, or Booster")
	end
	if definition.Strategy ~= definition.Category then
		issue("Strategy", "matching reusable category strategy")
	end
	if definition.Acquisition ~= "Shop" and definition.Acquisition ~= "Wheel" then
		issue("Acquisition", "Shop or Wheel")
	end
	if definition.Acquisition == "Shop" then
		if not Validation.integer(definition.Price, 1, 1000000000) then
			issue("Price", "positive whole coin amount")
		end
	elseif definition.Price ~= nil then
		issue("Price", "omitted for Wheel-only gear")
	end
	if definition.Category == "Melee" or definition.Category == "Gun" then
		if not Validation.finite(definition.Damage) or (definition.Damage :: number) <= 0 then
			issue("Damage", "positive finite source damage")
		end
	elseif definition.Damage ~= nil then
		issue("Damage", "omitted for Booster gear")
	end
	if definition.Category == "Gun" then
		if not Validation.integer(definition.LoadedAmmo, 1, 100000) then
			issue("LoadedAmmo", "positive whole magazine size")
		end
		if not Validation.integer(definition.ReserveAmmo, 0, 100000) then
			issue("ReserveAmmo", "whole nonnegative reserve")
		end
	elseif definition.LoadedAmmo ~= nil or definition.ReserveAmmo ~= nil then
		issue("Ammo", "omitted for non-gun gear")
	end
	if
		definition.WalkSpeedMultiplier ~= nil
		and (not Validation.finite(definition.WalkSpeedMultiplier) or definition.WalkSpeedMultiplier <= 0)
	then
		issue("WalkSpeedMultiplier", "positive finite multiplier")
	end
	if definition.Ability then
		if definition.Ability.Id == "" or definition.Ability.InputAction == "" then
			issue("Ability", "named ability and input action")
		end
		if
			not Validation.finite(definition.Ability.CooldownSeconds)
			or definition.Ability.CooldownSeconds < 0
		then
			issue("Ability.CooldownSeconds", "finite nonnegative duration")
		end
	end
	return errors
end

local function idOf(definition: GearDefinition): string
	return definition.Id
end
local function freeze(definition: GearDefinition)
	DeepFreeze.freeze((definition :: unknown) :: DeepFreeze.DataTable)
end
local registry = Registry.new(idOf, validate, freeze)

--[=[ Discover every sibling definition module; Types is the only support module. ]=]
for _, child in script:GetChildren() do
	if child:IsA("ModuleScript") and child.Name ~= "Types" then
		local definition = require(child) :: GearDefinition
		registry:add(definition)
	end
end
registry:seal()

local definitions = registry:all()
local byId: { [string]: GearDefinition } = {}
for _, definition in definitions do
	byId[definition.Id] = definition
end
local catalog: Catalog = { Definitions = definitions, ById = byId }
DeepFreeze.freeze((catalog :: unknown) :: DeepFreeze.DataTable)

return catalog
