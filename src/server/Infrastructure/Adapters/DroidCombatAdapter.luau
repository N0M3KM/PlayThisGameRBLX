--!strict
-- Composition-only bridge: domain D receives ports, never imports C implementation modules.
local Shared = game:GetService("ReplicatedStorage").Shared
local Http = game:GetService("HttpService")
local Combat = require(Shared.Contracts.DroidCombat)
local Payloads = require(Shared.Contracts.Payloads)
local Domain = require(Shared.Contracts.DomainInterfaces)
local Result = require(Shared.Contracts.Result)
local Config = require(Shared.Config.Combat)
local World = require(script.Parent.Parent.Parent.Services.Combat.CombatWorld)
local Rig = require(script.Parent.Parent.Parent.Services.Combat.RigAdapter)
local Projectiles = require(script.Parent.Parent.Parent.Services.Combat.ProjectileService.Implementation)
local ProjectileTypes = require(script.Parent.Parent.Parent.Services.Combat.ProjectileService.Types)
export type Options = {
	World: World.World,
	Damage: Domain.DamageService,
	Stats: Domain.StatService,
	Status: Domain.StatusEffectService,
	Rig: Rig.Api,
	active: (number) -> boolean,
	transport: ProjectileTypes.Transport?,
}
local Adapter = {}
local function key(entity: Payloads.EntityRef, kind: string): string
	return `{entity.RoundId}:{entity.Generation}:{entity.Id}:{kind}`
end

--[=[ D shots traverse C's single hit/damage pipeline. Missing FastCast transport remains NotReady. ]=]
function Adapter.new(options: Options)
	local weapons: { [string]: Combat.Shot } = {}
	local destroyed = false
	local projectiles = Projectiles.new(options.transport, {
		weapon = function(source, gearId)
			local shot = weapons[key(source, gearId)]
			local found, root = options.World.resolve(source), options.World.root(source)
			if destroyed or not shot or not found.Ok or not root or found.Value.Faction == "Player" then
				return Result.failure("NotReady")
			end
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			local model = options.World.model(source)
			params.FilterDescendantsInstances = if model then { model } else {}
			local position = root.Position
			return Result.success({
				Damage = shot.Damage,
				Speed = shot.Speed,
				Range = shot.Range,
				Faction = found.Value.Faction,
				Muzzle = { X = position.X, Y = position.Y, Z = position.Z },
				RaycastParams = params,
			})
		end,
		current = function(source, _id)
			local found = options.World.resolve(source)
			return found.Ok and found.Value.Hp > 0 and options.active(source.RoundId)
		end,
		roundActive = options.active,
		hitEntity = function(hit)
			return if typeof(hit) == "Instance" then options.World.fromPart(hit) else nil
		end,
		applyDamage = function(request)
			return options.Damage:Apply(request)
		end,
	}, Config, Http:GenerateGUID(false))
	projectiles:Init()
	projectiles:Start()
	local port: Combat.Port<Model> = {
		stats = options.Stats,
		controlLocked = options.Rig.controlLocked,
		refresh = options.Rig.refresh,
		register = function(entity, model, faction, immune, owner)
			if destroyed then
				return Result.failure("NotReady")
			end
			return options.World.register({
				Entity = entity,
				Model = model,
				Faction = faction,
				BulletImmune = immune,
				OwnerUserId = owner,
			})
		end,
		unregister = function(entity)
			options.Status:Clear(entity)
			options.Stats:Clear(entity)
			options.Rig.clear(entity)
			options.World.remove(entity)
			weapons[key(entity, "droid_bullet")], weapons[key(entity, "droid_paper")] = nil, nil
		end,
		model = options.World.model,
		damage = options.Damage,
		status = options.Status,
		projectile = function(shot)
			if destroyed then
				return Result.failure("NotReady")
			end
			local id = if shot.Kind == "Bullet" then "droid_bullet" else "droid_paper"
			weapons[key(shot.Source, id)] = table.clone(shot)
			local result = projectiles:Cast({
				Source = shot.Source,
				Origin = shot.Origin,
				Direction = shot.Direction,
				GearId = id,
				ShotId = shot.ShotId,
			})
			return if result.Ok then Result.success(true) else Result.failure(result.Code)
		end,
	}
	return table.freeze({
		Port = table.freeze(port),
		Projectiles = projectiles,
		clearRound = function(roundId: number)
			local cancelled = projectiles:CancelRound(roundId)
			for id, shot in weapons do
				if shot.Source.RoundId == roundId then
					weapons[id] = nil
				end
			end
			return cancelled
		end,
		destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			projectiles:Destroy()
			table.clear(weapons)
		end,
	})
end
return table.freeze(Adapter)
