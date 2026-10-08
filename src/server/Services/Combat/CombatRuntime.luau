--!strict
local Players = game:GetService("Players")
local Http = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Domain = require(Shared.Contracts.DomainInterfaces)
local Payloads = require(Shared.Contracts.Payloads)
local Result = require(Shared.Contracts.Result)
local Service = require(Shared.Contracts.Service)
local Gears = require(Shared.Config.Gears)
local GameConfig = require(Shared.Config.Game)
local Config = require(Shared.Config.Combat)
local World = require(script.Parent.CombatWorld)
local Gateway = require(script.Parent.CombatGateway)
local RemoteBinding = require(script.Parent.CombatRemoteBinding)
local Damage = require(script.Parent.DamageService.Implementation)
local Stats = require(script.Parent.StatService.Implementation)
local Statuses = require(script.Parent.StatusEffectService.Implementation)
local Rig = require(script.Parent.RigAdapter)
local Loadout = require(script.Parent.LoadoutService.Implementation)
local LoadoutTypes = require(script.Parent.LoadoutService.Types)
local Projectiles = require(script.Parent.ProjectileService.Implementation)
local ProjectileTypes = require(script.Parent.ProjectileService.Types)
local Gear = require(script.Parent.GearService.Implementation)
local GearTypes = require(script.Parent.GearService.Types)
local Melee = require(script.Parent.Parent.Parent.Behaviors.Gear.Melee)
export type Tuning = GearTypes.Tuning
export type Options = {
	data: Domain.DataService,
	players: Domain.PlayerStateService,
	selection: {
		read: (number) -> Result.Result<LoadoutTypes.Selection>,
		write: (number, LoadoutTypes.Selection, string, () -> boolean) -> Result.Result<boolean>,
	},
	catalog: (LoadoutTypes.Category, string) -> Result.Result<LoadoutTypes.Definition>,
	Templates: Instance,
	clock: () -> number,
	after: (number, () -> ()) -> () -> (),
	active: (number) -> boolean,
	tuning: (string) -> Tuning?,
	transport: ProjectileTypes.Transport?,
	ability: ((Payloads.EntityRef, string, string) -> Result.Result<boolean>)?,
	onFact: ((Payloads.DamageFact) -> ())?,
}
local CombatRuntime = {}

local function playerEntity(userId: number, roundId: number, generation: number): Payloads.EntityRef
	local identity = tostring(userId):gsub("%-", "n")
	return { Id = `player_{identity}`, RoundId = roundId, Generation = generation }
end

--[=[ Explicit composition boundary: no profiles, packages or remotes start at require time.
	The owner supplies data, selection persistence, active-round state, tuning and FastCast transport.
]=]
function CombatRuntime.new(options: Options)
	local world = World.new()
	local destroyed = false
	local registeredPlayers: { [number]: Payloads.EntityRef } = {}
	local rig: Rig.Api? = nil
	local stats = Stats.new({
		base = world.base,
		current = world.current,
		Policy = { WalkSpeedStat = "WalkSpeed", WalkSpeedCap = GameConfig.Proposals.WalkSpeedHardCap },
		changed = function(entity)
			if rig then
				rig.refresh(entity)
			end
		end,
	})
	rig = Rig.new({
		model = world.model,
		current = world.current,
		stats = stats,
		MaxImpulse = Config.MaxImpulse,
	})
	local rigOwner = rig :: Rig.Api
	local statuses = Statuses.new({
		stats = stats,
		current = world.current,
		clock = options.clock,
		after = options.after,
		definitions = { stun = { Modifiers = {}, Stun = true }, ragdoll = { Modifiers = {}, Ragdoll = true } },
		movement = rigOwner.controls,
	})
	local damage = Damage.new({
		resolve = world.resolve,
		roundActive = options.active,
		writeHp = world.writeHp,
		modifiers = function(source, target, request)
			local dealt, taken = stats:Resolve(source.Ref), stats:Resolve(target.Ref)
			if not dealt.Ok or not taken.Ok then
				return Result.failure("NotReady")
			end
			local category = if request.Kind == "Melee"
				then "MeleeDamage"
				elseif request.Kind == "Projectile" then "GunDamage"
				else "DamageDealt"
			local factor = if category == "DamageDealt" then 1 else dealt.Value[category] or 1
			return Result.success({
				Dealt = (dealt.Value.DamageDealt or 1) * factor,
				Taken = taken.Value.DamageTaken or 1,
			})
		end,
	}, Config, Http:GenerateGUID(false), options.onFact)
	local gear: GearTypes.Api? = nil
	local function clearPlayer(userId: number)
		local entity = registeredPlayers[userId]
		registeredPlayers[userId] = nil
		if gear then
			pcall(gear.Clear, gear, userId)
		end
		if not entity then
			return
		end
		-- Each generation owns its status timers, modifier layers and rig connections.
		-- Preserve authoritative damage facts until the enclosing round is cleared.
		pcall(statuses.Clear, statuses, entity)
		pcall(stats.Clear, stats, entity)
		pcall(rigOwner.clear, entity)
		world.remove(entity)
	end
	local loadout = Loadout.new({
		data = options.data,
		players = options.players,
		selection = options.selection,
		catalog = options.catalog,
		Templates = options.Templates,
		player = function(userId)
			return Players:GetPlayerByUserId(userId)
		end,
		requestId = function()
			return Http:GenerateGUID(false)
		end,
		onCharacterGranted = function(userId, roundId, generation)
			if destroyed then
				return Result.failure("NotReady")
			end
			local entity = playerEntity(userId, roundId, generation)
			local previous = registeredPlayers[userId]
			if previous and (previous.RoundId ~= roundId or previous.Generation ~= generation) then
				clearPlayer(userId)
			end
			if not world.current(entity) then
				local player = Players:GetPlayerByUserId(userId)
				if not player or not player.Character then
					return Result.failure("NotReady")
				end
				local registered = world.register({
					Entity = entity,
					Model = player.Character,
					Faction = "Player",
					OwnerUserId = userId,
				})
				if not registered.Ok then
					return registered
				end
			end
			registeredPlayers[userId] = table.freeze(entity)
			return Result.success(true)
		end,
		onGranted = function(userId, roundId, generation, slot, tool)
			if destroyed or not gear then
				return Result.failure("NotReady")
			end
			gear:BindTool(userId, roundId, generation, slot, tool)
			return Result.success(true)
		end,
		onClear = clearPlayer,
	})
	local function sourceTool(source: Payloads.EntityRef, gearId: string): Tool?
		local found = world.resolve(source)
		if not found.Ok or found.Value.Hp <= 0 or not found.Value.OwnerUserId then
			return nil
		end
		local userId = found.Value.OwnerUserId
		local locked = loadout:GetLocked(userId, source.RoundId)
		if not locked.Ok then
			return nil
		end
		for slot, id in locked.Value.GearIds do
			if id == gearId then
				local tool = loadout:ValidateTool(userId, source.RoundId, source.Generation, slot)
				if tool.Ok then
					return tool.Value
				end
			end
		end
		return nil
	end
	local projectiles = Projectiles.new(options.transport, {
		weapon = function(source, gearId)
			local definition, tuning = Gears.ById[gearId], options.tuning(gearId)
			local tool = sourceTool(source, gearId)
			local handle = if tool then tool:FindFirstChild("Handle") else nil
			local muzzle = if handle then handle:FindFirstChild("MuzzleAttachment") else nil
			local found = world.resolve(source)
			if
				not definition
				or definition.Category ~= "Gun"
				or not definition.Damage
				or not tuning
				or not tuning.Speed
				or not tuning.Range
				or not muzzle
				or not muzzle:IsA("Attachment")
				or not found.Ok
			then
				return Result.failure("NotReady")
			end
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			local model = world.model(source)
			params.FilterDescendantsInstances = if model then { model } else {}
			local position = muzzle.WorldPosition
			return Result.success({
				Damage = definition.Damage,
				Speed = tuning.Speed,
				Range = tuning.Range,
				Faction = found.Value.Faction,
				Muzzle = { X = position.X, Y = position.Y, Z = position.Z },
				RaycastParams = params,
			})
		end,
		current = function(source, _gearId)
			local found = world.resolve(source)
			if not found.Ok or found.Value.Hp <= 0 or not found.Value.OwnerUserId then
				return false
			end
			local state = options.players:Get(found.Value.OwnerUserId)
			return state.Ok
				and state.Value.State == "InRound"
				and state.Value.RoundId == source.RoundId
				and state.Value.CharacterGeneration == source.Generation
		end,
		roundActive = options.active,
		hitEntity = function(hit)
			return if typeof(hit) == "Instance" then world.fromPart(hit) else nil
		end,
		applyDamage = function(request)
			return damage:Apply(request)
		end,
	}, Config, Http:GenerateGUID(false))
	local melee = Melee.new({
		world = world,
		damage = damage,
		knockback = function(entity, velocity)
			local root = world.root(entity)
			if root and not root.Anchored then
				-- Tuning specifies change in velocity; ApplyImpulse consumes mass times velocity.
				rigOwner.knockback(entity, velocity * root.AssemblyMass)
			end
		end,
	})
	gear = Gear.new({
		loadout = loadout,
		stats = stats,
		projectiles = projectiles,
		projectilesReady = function()
			return options.transport ~= nil
		end,
		clock = options.clock,
		active = options.active,
		tuning = options.tuning,
		ability = options.ability,
		entity = function(userId, roundId, generation)
			return playerEntity(userId, roundId, generation)
		end,
		melee = function(entity, amount, tuning)
			if not tuning.Range or not tuning.Width or not tuning.Height then
				return Result.failure("NotReady")
			end
			return melee(entity, {
				Damage = amount,
				Range = tuning.Range,
				Width = tuning.Width,
				Height = tuning.Height,
				KnockbackSpeed = tuning.KnockbackSpeed,
			})
		end,
	})
	local gearOwner = gear :: GearTypes.Api
	local gateway = Gateway.new({
		clock = options.clock,
		state = function(userId)
			return options.players:Get(userId)
		end,
		active = options.active,
		use = function(userId, intent)
			return gearOwner:Use(userId, intent)
		end,
		reload = function(userId, intent)
			return gearOwner:Reload(userId, intent)
		end,
		ability = function(userId, intent)
			return gearOwner:Ability(userId, intent)
		end,
	})
	local services: { Service.Interface } = { stats, statuses, damage, loadout, projectiles, gearOwner }
	local network: RemoteBinding.Binding? = nil
	for _, service in services do
		service:Init()
		service:Start()
	end
	local removing = Players.PlayerRemoving:Connect(function(player)
		gateway.remove(player.UserId)
		loadout:Clear(player.UserId)
		clearPlayer(player.UserId)
	end)
	local function clearRound(roundId: number): Result.Result<boolean>
		local cancelled = projectiles:CancelRound(roundId)
		loadout:ClearRound(roundId)
		statuses:ClearRound(roundId)
		stats:ClearRound(roundId)
		rigOwner.clearRound(roundId)
		world.clearRound(roundId)
		local cleared = damage:ClearRound(roundId)
		return if not cancelled.Ok
			then Result.failure(cancelled.Code)
			elseif not cleared.Ok then Result.failure(cleared.Code)
			else Result.success(true)
	end
	return table.freeze({
		World = world,
		Damage = damage,
		Stats = stats,
		Status = statuses,
		Rig = rigOwner,
		Loadout = loadout,
		Projectiles = projectiles,
		Gear = gearOwner,
		Gateway = gateway,
		bindRemotes = function(folder: Folder): Result.Result<boolean>
			if destroyed then
				return Result.failure("NotReady")
			elseif network then
				return Result.failure("WrongState")
			end
			local bound = RemoteBinding.bind(folder, gateway)
			if not bound.Ok then
				return Result.failure(bound.Code)
			end
			network = bound.Value
			return Result.success(true)
		end,
		playerEntity = playerEntity,
		beginRound = function(roundId: number)
			return if destroyed then Result.failure("NotReady") else damage:BeginRound(roundId)
		end,
		clearRound = clearRound,
		destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			removing:Disconnect()
			if network then
				network.destroy()
				network = nil
			end
			gateway.destroy()
			for index = #services, 1, -1 do
				services[index]:Destroy()
			end
			local retained = {}
			for userId in registeredPlayers do
				table.insert(retained, userId)
			end
			for _, userId in retained do
				clearPlayer(userId)
			end
			rigOwner.destroy()
			world.destroy()
		end,
	})
end

return table.freeze(CombatRuntime)
