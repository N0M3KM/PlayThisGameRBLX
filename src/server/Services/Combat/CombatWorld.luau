--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage").Shared
local Payloads = require(Shared.Contracts.Payloads)
local States = require(Shared.Contracts.States)
local Result = require(Shared.Contracts.Result)
local Validation = require(Shared.Registry.Validation)
local Config = require(Shared.Config.Combat)
local DamageTypes = require(script.Parent.DamageService.Types)
export type Registration = {
	Entity: Payloads.EntityRef,
	Model: Model,
	Faction: States.Faction,
	OwnerUserId: number?,
	IsBoss: boolean?,
	BulletImmune: boolean?,
	BaseStats: { [string]: number }?,
}
type Entry = Registration & { Humanoid: Humanoid, Root: BasePart, Base: { [string]: number } }
export type World = {
	register: (Registration) -> Result.Result<boolean>,
	resolve: (Payloads.EntityRef) -> Result.Result<DamageTypes.Entity>,
	current: (Payloads.EntityRef) -> boolean,
	base: (Payloads.EntityRef) -> Result.Result<{ [string]: number }>,
	model: (Payloads.EntityRef) -> Model?,
	root: (Payloads.EntityRef) -> BasePart?,
	fromPart: (Instance) -> Payloads.EntityRef?,
	writeHp: (DamageTypes.Entity, number, number) -> Result.Result<number>,
	remove: (Payloads.EntityRef) -> (),
	clearRound: (number) -> (),
	destroy: () -> (),
}
local CombatWorld = {}

local function key(entity: Payloads.EntityRef): string
	return `{entity.RoundId}:{entity.Generation}:{entity.Id}`
end

--[=[ Server registration owns entity identity. Requests never resolve arbitrary paths or client Instances. ]=]
function CombatWorld.new(): World
	local entries: { [string]: Entry } = {}
	local models: { [Model]: string } = {}
	local count = 0
	local destroyed = false
	local function entry(entity: Payloads.EntityRef): Entry?
		if destroyed then
			return nil
		end
		local found = entries[key(entity)]
		if
			not found
			or not found.Model:IsDescendantOf(Workspace)
			or found.Humanoid.Parent ~= found.Model
			or not found.Root:IsDescendantOf(found.Model)
		then
			return nil
		end
		if found.Faction == "Player" then
			local player = if found.OwnerUserId then Players:GetPlayerByUserId(found.OwnerUserId) else nil
			if not player or player.Character ~= found.Model then
				return nil
			end
		end
		return found
	end
	local function remove(entity: Payloads.EntityRef)
		local identity = key(entity)
		local found = entries[identity]
		if found then
			models[found.Model], entries[identity] = nil, nil
			count -= 1
		end
	end
	return table.freeze({
		register = function(input: Registration): Result.Result<boolean>
			if destroyed then
				return Result.failure("NotReady")
			end
			local entity, model = input.Entity, input.Model
			if
				not Validation.id(entity.Id)
				or not Validation.integer(entity.Generation, 1, 9007199254740991)
				or not Validation.integer(entity.RoundId, 1, 9007199254740991)
			then
				return Result.failure("InvalidRequest")
			end
			if input.Faction ~= "Player" and input.Faction ~= "Hostile" and input.Faction ~= "Allied" then
				return Result.failure("InvalidRequest")
			end
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart")
			if
				not model:IsDescendantOf(Workspace)
				or not humanoid
				or not root
				or not root:IsA("BasePart")
				or not Validation.finite(humanoid.MaxHealth)
				or humanoid.MaxHealth <= 0
			then
				return Result.failure("InvalidRequest")
			end
			if input.OwnerUserId and not Validation.playerId(input.OwnerUserId, 9007199254740991) then
				return Result.failure("InvalidRequest")
			end
			if input.Faction == "Player" then
				local player = if input.OwnerUserId then Players:GetPlayerByUserId(input.OwnerUserId) else nil
				if not player or player.Character ~= model then
					return Result.failure("NotOwned")
				end
			end
			local identity = key(entity)
			if entries[identity] or models[model] then
				return Result.failure("WrongState")
			end
			if count >= Config.MaxEntitiesPerRound then
				return Result.failure("LimitReached")
			end
			local base = {
				WalkSpeed = humanoid.WalkSpeed,
				JumpPower = humanoid.JumpPower,
				JumpHeight = humanoid.JumpHeight,
				MaxHP = humanoid.MaxHealth,
				DamageDealt = 1,
				MeleeDamage = 1,
				GunDamage = 1,
				DamageTaken = 1,
			}
			local overrides: { [string]: number } = input.BaseStats or {}
			for name, value in overrides do
				if not Validation.id(name:lower()) or not Validation.finite(value) or value < 0 then
					return Result.failure("InvalidRequest")
				end
				base[name] = value
			end
			if input.Faction ~= "Player" and not root.Anchored then
				local owned = pcall(function()
					root:SetNetworkOwner(nil)
				end)
				if not owned then
					return Result.failure("Unavailable")
				end
			end
			entries[identity] = {
				Entity = table.freeze(table.clone(entity)),
				Model = model,
				Humanoid = humanoid,
				Root = root,
				Faction = input.Faction,
				OwnerUserId = input.OwnerUserId,
				IsBoss = input.IsBoss == true,
				BulletImmune = input.BulletImmune == true,
				Base = table.freeze(base),
			}
			models[model], count = identity, count + 1
			return Result.success(true)
		end,
		resolve = function(entity: Payloads.EntityRef): Result.Result<DamageTypes.Entity>
			local found = entry(entity)
			if not found then
				return Result.failure("StaleRound")
			end
			return Result.success(table.freeze({
				Ref = found.Entity,
				Faction = found.Faction,
				Hp = found.Humanoid.Health,
				MaxHp = found.Humanoid.MaxHealth,
				IsBoss = found.IsBoss == true,
				BulletImmune = found.BulletImmune == true,
				OwnerUserId = found.OwnerUserId,
			}))
		end,
		current = function(entity: Payloads.EntityRef): boolean
			return entry(entity) ~= nil
		end,
		base = function(entity: Payloads.EntityRef): Result.Result<{ [string]: number }>
			local found = entry(entity)
			return if found then Result.success(table.clone(found.Base)) else Result.failure("StaleRound")
		end,
		model = function(entity: Payloads.EntityRef): Model?
			local found = entry(entity)
			return if found then found.Model else nil
		end,
		root = function(entity: Payloads.EntityRef): BasePart?
			local found = entry(entity)
			return if found then found.Root else nil
		end,
		fromPart = function(part: Instance): Payloads.EntityRef?
			local current: Instance? = part
			while current and current ~= Workspace do
				if current:IsA("Model") then
					local identity = models[current]
					local found = if identity then entries[identity] else nil
					if found and entry(found.Entity) then
						return found.Entity
					end
				end
				current = current.Parent
			end
			return nil
		end,
		writeHp = function(
			entity: DamageTypes.Entity,
			expected: number,
			nextHp: number
		): Result.Result<number>
			local found = entry(entity.Ref)
			if not found or found.Humanoid.Health ~= expected then
				return Result.failure("WrongState")
			end
			if not Validation.finite(nextHp) or nextHp < 0 or nextHp > expected then
				return Result.failure("InvalidRequest")
			end
			found.Humanoid:TakeDamage(expected - nextHp)
			return Result.success(found.Humanoid.Health)
		end,
		remove = remove,
		clearRound = function(roundId: number)
			for _, found in entries do
				if found.Entity.RoundId == roundId then
					remove(found.Entity)
				end
			end
		end,
		destroy = function()
			destroyed = true
			table.clear(entries)
			table.clear(models)
			count = 0
		end,
	})
end

return table.freeze(CombatWorld)
