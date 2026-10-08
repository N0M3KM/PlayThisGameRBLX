--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local AI = require(Shared.Contracts.DroidAI)
local Combat = require(Shared.Contracts.DroidCombat)
local Definitions = require(Shared.Config.Droids.Types)
local Config = require(Shared.Config.DroidRuntime)
local Specs = {}
local function positive(value: number?): boolean
	return value ~= nil and value == value and value > 0 and value < math.huge
end

--[=[ Source values remain in definitions. Missing values stay absent until the owner supplies tuning. ]=]
function Specs.build(definition: Definitions.DroidDefinition, tuning: Combat.Tuning?): { AI.Ability }
	local values: Combat.Tuning = tuning or {}
	local parameters = definition.AbilityParams
	local result: { AI.Ability } = {}
	for _, id in definition.Abilities do
		local ability: AI.Ability? = nil
		if id == "melee" then
			ability = {
				Id = id,
				Range = Config.MeleeRange,
				CooldownSeconds = definition.Melee.CooldownSeconds or values.WindMeleeCooldownSeconds,
				Damage = definition.Melee.Damage,
			} :: AI.Ability
		elseif id == "lunge" then
			ability = {
				Id = id,
				Range = parameters.LungeRange,
				CooldownSeconds = if positive(values.LungeSpeed)
						and positive(values.LungeStunSeconds)
						and positive(values.LungeRagdollSeconds)
					then parameters.LungeCooldownSeconds
					else nil,
				Damage = definition.Melee.Damage,
				DurationSeconds = values.LungeStunSeconds,
				RecoverySeconds = parameters.SitRecoverSeconds,
			} :: AI.Ability
		elseif id == "shoot" then
			ability = {
				Id = id,
				Range = parameters.ShootRange,
				CooldownSeconds = if positive(values.ProjectileSpeed)
					then values.ShootCooldownSeconds
					else nil,
				Damage = values.ShootDamage,
			} :: AI.Ability
		elseif id == "throw_paper" then
			ability = {
				Id = id,
				Range = parameters.ThrowPaperRange,
				CooldownSeconds = if positive(values.ProjectileSpeed)
					then parameters.ThrowPaperCooldownSeconds
					else nil,
				Damage = parameters.ThrowPaperDamage,
			} :: AI.Ability
		elseif id == "shock_gun" then
			ability = {
				Id = id,
				Range = values.ShockRange,
				CooldownSeconds = parameters.ShockGunCooldownSeconds,
				DurationSeconds = parameters.ShockGunStunSeconds,
			} :: AI.Ability
		end
		if ability then
			table.insert(result, table.freeze(ability))
		end
	end
	return table.freeze(result)
end
return table.freeze(Specs)
