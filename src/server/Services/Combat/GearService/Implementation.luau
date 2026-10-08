--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Payloads = require(Shared.Contracts.Payloads)
local Requests = require(Shared.Contracts.Requests)
local Schemas = require(Shared.Contracts.RequestSchemas)
local Service = require(Shared.Contracts.Service)
local Result = require(Shared.Contracts.Result)
local Gears = require(Shared.Config.Gears)
local GearTypes = require(Shared.Config.Gears.Types)
local Config = require(Shared.Config.Combat)
local Validation = require(Shared.Registry.Validation)
local Ammo = require(Shared.Util.Combat.AmmoModel)
local Cooldown = require(Shared.Util.Combat.CooldownTracker)
local Scope = require(Shared.Util.Scope)
local Lifecycle = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceLifecycle)
local Booster = require(script.Parent.Parent.Parent.Parent.Behaviors.Gear.Booster)
local Types = require(script.Parent.Types)
type Weapon = {
	Entity: Payloads.EntityRef,
	Definition: GearTypes.GearDefinition,
	Ammo: Ammo.Model?,
	Cooldown: Cooldown.Tracker,
	Scope: Scope.Scope,
	Tool: Tool,
}
local Implementation = {}

--[=[ Public commands revalidate the private Tool registry. Only definitions and server tuning determine effects. ]=]
function Implementation.new(deps: Types.Dependencies): Types.Api
	local weapons: { [number]: { [number]: Weapon } } = {}
	local owner = Scope.new()
	local function clear(userId: number)
		local previous = weapons[userId]
		weapons[userId] = nil
		if not previous then
			return
		end
		for _, weapon in previous do
			weapon.Scope:destroy()
			weapon.Cooldown.clear()
			if weapon.Ammo then
				weapon.Ammo.cancelReload()
			end
		end
	end
	local facade = Lifecycle.new("GearService", owner, {
		Stop = function()
			for userId in weapons do
				clear(userId)
			end
		end,
	})
	local service = (facade :: unknown) :: Types.Api
	local function resolve(userId: number, intent: Requests.UseGear): Result.Result<Weapon>
		if not service:IsStarted() or not deps.active(intent.RoundId) then
			return Result.failure("WrongState")
		end
		local tool =
			deps.loadout:ValidateTool(userId, intent.RoundId, intent.CharacterGeneration, intent.GearSlot)
		if not tool.Ok then
			return Result.failure(tool.Code)
		end
		local slots = weapons[userId]
		local weapon = if slots then slots[intent.GearSlot] else nil
		if
			not weapon
			or weapon.Tool ~= tool.Value
			or weapon.Entity.RoundId ~= intent.RoundId
			or weapon.Entity.Generation ~= intent.CharacterGeneration
		then
			return Result.failure("StaleRound")
		end
		return Result.success(weapon)
	end
	service.BindTool = function(
		_self: Service.Interface,
		userId: number,
		roundId: number,
		generation: number,
		slot: number,
		tool: Tool
	)
		local entity = deps.entity(userId, roundId, generation)
		local locked = deps.loadout:GetLocked(userId, roundId)
		if not entity or not locked.Ok then
			return
		end
		local id = locked.Value.GearIds[slot]
		local definition = if id then Gears.ById[id] else nil
		if not definition then
			return
		end
		local slots = weapons[userId] or {}
		weapons[userId] = slots
		if slots[slot] then
			slots[slot].Scope:destroy()
		end
		local scope = owner:child()
		local weapon: Weapon = {
			Entity = table.freeze(table.clone(entity)),
			Definition = definition,
			Cooldown = Cooldown.new(2),
			Scope = scope,
			Tool = tool,
		}
		if definition.LoadedAmmo and definition.ReserveAmmo then
			weapon.Ammo = Ammo.new(
				definition.LoadedAmmo,
				definition.LoadedAmmo,
				definition.ReserveAmmo,
				Config.MaxReserveAmmo
			)
		end
		slots[slot] = weapon
		local function removePassive()
			Booster.remove(deps.stats, entity, definition.Id)
		end
		scope:add(removePassive)
		local equipped = tool.Equipped:Connect(function()
			if definition.Category ~= "Booster" then
				return
			end
			local checked = deps.loadout:ValidateTool(userId, roundId, generation, slot)
			if not checked.Ok then
				return
			end
			local tuning = deps.tuning(definition.Id)
			Booster.apply(deps.stats, entity, definition.Id, {
				WalkSpeedMultiplier = definition.WalkSpeedMultiplier,
				JumpPowerMultiplier = if definition.JumpMultiplierTodo and tuning
					then tuning.JumpMultiplier
					else nil,
			})
		end)
		local unequipped = tool.Unequipped:Connect(removePassive)
		scope:add(function()
			equipped:Disconnect()
			unequipped:Disconnect()
		end)
		local destroying = tool.Destroying:Connect(function()
			scope:destroy()
			if slots[slot] == weapon then
				slots[slot] = nil
			end
		end)
		scope:add(function()
			destroying:Disconnect()
		end)
	end
	service.Use = function(
		_self: Service.Interface,
		userId: number,
		input: Requests.UseGear
	): Result.Result<boolean>
		local checked = Schemas.useGear(input)
		if not checked.Ok then
			return Result.failure(checked.Code)
		end
		local intent = checked.Value
		local found = resolve(userId, intent)
		if not found.Ok then
			return Result.failure(found.Code)
		end
		local weapon = found.Value
		local definition, tuning = weapon.Definition, deps.tuning(weapon.Definition.Id)
		if definition.Category == "Booster" then
			return Result.failure("WrongState")
		end
		if
			not tuning
			or not tuning.CooldownSeconds
			or not Validation.finite(tuning.CooldownSeconds)
			or tuning.CooldownSeconds <= 0
		then
			return Result.failure("NotReady")
		end
		local now = deps.clock()
		if not weapon.Cooldown.ready("fire", now) then
			return Result.failure("Cooldown")
		end
		if definition.Category == "Gun" then
			if
				not tuning.Speed
				or not Validation.finite(tuning.Speed)
				or tuning.Speed <= 0
				or not tuning.Range
				or not Validation.finite(tuning.Range)
				or tuning.Range <= 0
			then
				return Result.failure("NotReady")
			end
			local handle = weapon.Tool:FindFirstChild("Handle")
			local muzzle = if handle then handle:FindFirstChild("MuzzleAttachment") else nil
			if
				not muzzle
				or not muzzle:IsA("Attachment")
				or not intent.AimOrigin
				or not intent.AimDirection
				or not weapon.Ammo
			then
				return Result.failure("InvalidRequest")
			end
			local origin = Vector3.new(intent.AimOrigin.X, intent.AimOrigin.Y, intent.AimOrigin.Z)
			if (origin - muzzle.WorldPosition).Magnitude > Config.MaxOriginDistance then
				return Result.failure("InvalidRequest")
			end
			if not deps.projectilesReady() or deps.projectiles.IsStub or not deps.projectiles:IsStarted() then
				return Result.failure("NotReady")
			end
			local fired = weapon.Ammo.fire(now)
			if not fired.Ok then
				return Result.failure(fired.Code)
			end
			local cooled = weapon.Cooldown.take("fire", now, tuning.CooldownSeconds)
			if not cooled.Ok then
				return cooled
			end
			-- Consumed ammo is never refunded after uncertain cast side effects.
			local cast = deps.projectiles:Cast({
				Source = weapon.Entity,
				Origin = intent.AimOrigin,
				Direction = intent.AimDirection,
				GearId = definition.Id,
				ShotId = intent.RequestId,
			})
			return if cast.Ok then Result.success(true) else Result.failure(cast.Code)
		end
		if not definition.Damage or not tuning.Range or not tuning.Width or not tuning.Height then
			return Result.failure("NotReady")
		end
		for _, dimension in { tuning.Range, tuning.Width, tuning.Height } do
			if not Validation.finite(dimension) or dimension <= 0 then
				return Result.failure("NotReady")
			end
		end
		local cooled = weapon.Cooldown.take("fire", now, tuning.CooldownSeconds)
		if not cooled.Ok then
			return cooled
		end
		local meleeTuning = table.clone(tuning)
		local effects = definition.Effects or {}
		if not table.find(effects, "MinorKnockback") and not table.find(effects, "KnockbackEveryHit") then
			meleeTuning.KnockbackSpeed = nil
		end
		return deps.melee(weapon.Entity, definition.Damage, meleeTuning)
	end
	service.Reload = function(
		_self: Service.Interface,
		userId: number,
		input: Requests.ReloadGear
	): Result.Result<boolean>
		local checked = Schemas.reloadGear(input)
		if not checked.Ok then
			return Result.failure(checked.Code)
		end
		local intent = (checked.Value :: unknown) :: Requests.UseGear
		local found = resolve(userId, intent)
		if not found.Ok then
			return Result.failure(found.Code)
		end
		local weapon, tuning = found.Value, deps.tuning(found.Value.Definition.Id)
		if not weapon.Ammo then
			return Result.failure("WrongState")
		end
		if not tuning or not tuning.ReloadSeconds then
			return Result.failure("NotReady")
		end
		local result = weapon.Ammo.reload(deps.clock(), tuning.ReloadSeconds)
		return if result.Ok then Result.success(true) else Result.failure(result.Code)
	end
	service.Ability = function(
		_self: Service.Interface,
		userId: number,
		input: Requests.UseAbility
	): Result.Result<boolean>
		local checked = Schemas.useAbility(input)
		if not checked.Ok then
			return Result.failure(checked.Code)
		end
		local found = resolve(userId, (checked.Value :: unknown) :: Requests.UseGear)
		if not found.Ok then
			return Result.failure(found.Code)
		end
		local weapon, ability = found.Value, found.Value.Definition.Ability
		if not ability then
			return Result.failure("WrongState")
		end
		if not deps.ability then
			return Result.failure("NotReady")
		end
		local cooled = weapon.Cooldown.take("ability", deps.clock(), ability.CooldownSeconds)
		if not cooled.Ok then
			return cooled
		end
		-- Ability strategies cannot resume against a later round or character.
		local callback = deps.ability
		local thread = coroutine.create(function()
			return callback(weapon.Entity, ability.Id, checked.Value.RequestId)
		end)
		local ok, outcome = coroutine.resume(thread)
		if not ok or coroutine.status(thread) ~= "dead" then
			pcall(coroutine.close, thread)
			return Result.failure("Unavailable")
		end
		if type(outcome) ~= "table" then
			return Result.failure("Unavailable")
		end
		if outcome.Ok == true and type(outcome.Value) == "boolean" then
			return Result.success(outcome.Value)
		elseif outcome.Ok == false and Result.isErrorCode(outcome.Code) then
			return Result.failure(outcome.Code)
		end
		return Result.failure("Unavailable")
	end
	service.Clear = function(_self: Service.Interface, userId: number): Result.Result<boolean>
		clear(userId)
		return Result.success(true)
	end
	service.GetAmmo = function(
		_self: Service.Interface,
		userId: number,
		slot: number
	): Result.Result<Ammo.Snapshot>
		local slots = weapons[userId]
		local weapon = if slots then slots[slot] else nil
		return if weapon and weapon.Ammo
			then Result.success(weapon.Ammo.snapshot(deps.clock()))
			else Result.failure("NotReady")
	end
	return service
end

return table.freeze(Implementation)
