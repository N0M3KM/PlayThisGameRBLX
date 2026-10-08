--!strict
-- Studio-only composition. No profile sessions, rewards, player Tools or event policy are started here.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Domain = require(Shared.Contracts.DomainInterfaces)
local Payloads = require(Shared.Contracts.Payloads)
local DroidAI = require(Shared.Contracts.DroidAI)
local Service = require(Shared.Contracts.Service)
local Result = require(Shared.Contracts.Result)
local Scope = require(Shared.Util.Scope)
local Maps = require(Shared.Config.Maps)
local Scenarios = require(Shared.Config.Scenarios)
local AIConfig = require(Shared.Config.AI)
local Server = script.Parent.Parent
local Combat = require(Server.Services.Combat.CombatRuntime)
local CombatAdapter = require(Server.Infrastructure.Adapters.DroidCombatAdapter)
local Droids = require(Server.Services.Droids.DroidRuntime)
local DroidPreview = {}

--[=[ Bind the existing Match facades to real D lifecycle/Actors and C's single damage/status pipeline. ]=]
function DroidPreview.new(
	resolve: (string) -> Service.Interface,
	services: { [string]: Service.Interface },
	assets: Instance,
	scope: Scope.Scope
)
	assert(game:GetService("RunService"):IsStudio(), "Droid preview is restricted to Studio")
	local players = (services.PlayerStateService :: unknown) :: Domain.PlayerStateService
	local function active(roundId: number): boolean
		local loop = (resolve("GameLoopService") :: unknown) :: Domain.GameLoopService
		local state = loop:GetState()
		return state.Ok and state.Value.RoundId == roundId and state.Value.State == "Active"
	end
	local function after(seconds: number, callback: () -> ()): () -> ()
		local thread = task.delay(seconds, callback)
		return function()
			if coroutine.status(thread) ~= "dead" then
				task.cancel(thread)
			end
		end
	end
	local combat = Combat.new({
		data = (services.DataService :: unknown) :: Domain.DataService,
		players = players,
		selection = {
			read = function()
				return Result.failure("NotReady")
			end,
			write = function()
				return Result.failure("NotReady")
			end,
		},
		catalog = function()
			return Result.failure("NotReady")
		end,
		Templates = assets:FindFirstChild("Gear") or assets,
		clock = os.clock,
		after = after,
		active = active,
		tuning = function()
			return nil
		end,
	})
	scope:add(combat.destroy)
	local adapter = CombatAdapter.new({
		World = combat.World,
		Damage = combat.Damage,
		Stats = combat.Stats,
		Status = combat.Status,
		Rig = combat.Rig,
		active = active,
	})
	scope:add(adapter.destroy)
	local registered: { [number]: Payloads.EntityRef } = {}
	local attackers: { [string]: Payloads.EntityRef } = {}
	local attackerCount = 0
	local function identity(entity: Payloads.EntityRef): string
		return `{entity.RoundId}:{entity.Generation}:{entity.Id}`
	end
	local applyDamage = combat.Damage.Apply
	combat.Damage.Apply = function(self: Service.Interface, request: Payloads.DamageRequest)
		local result = applyDamage(self, request)
		if
			result.Ok
			and result.Value.ActualHpLoss > 0
			and request.Source
			and (attackers[identity(request.Target)] ~= nil or attackerCount < AIConfig.MaxAgents)
		then
			if not attackers[identity(request.Target)] then
				attackerCount += 1
			end
			attackers[identity(request.Target)] = table.freeze(table.clone(request.Source))
		end
		return result
	end
	local function clearPlayer(userId: number)
		local previous = registered[userId]
		registered[userId] = nil
		if previous then
			if attackers[identity(previous)] then
				attackers[identity(previous)] = nil
				attackerCount -= 1
			end
			adapter.Port.unregister(previous)
		end
	end
	local function playerChanged(snapshot: Payloads.PlayerStateSnapshot)
		local previous = registered[snapshot.UserId]
		if snapshot.State ~= "InRound" or not snapshot.RoundId then
			clearPlayer(snapshot.UserId)
			return
		end
		if
			previous
			and previous.RoundId == snapshot.RoundId
			and previous.Generation == snapshot.CharacterGeneration
		then
			return
		end
		clearPlayer(snapshot.UserId)
		local player = Players:GetPlayerByUserId(snapshot.UserId)
		if not player or not player.Character then
			return
		end
		local entity = combat.playerEntity(snapshot.UserId, snapshot.RoundId, snapshot.CharacterGeneration)
		local result = combat.World.register({
			Entity = entity,
			Model = player.Character,
			Faction = "Player",
			OwnerUserId = snapshot.UserId,
		})
		if result.Ok then
			registered[snapshot.UserId] = entity
		end
	end
	local droidAssets = assets:FindFirstChild("Droids")
	assert(droidAssets, "Droid preview requires primitive droid templates")
	local live = Instance.new("Folder")
	live.Name = "MatchDroids"
	live.Parent = workspace
	scope:add(function()
		live:Destroy()
	end)
	local runtime = Droids.new({
		Templates = droidAssets,
		Parent = live,
		Storage = game:GetService("ServerStorage"),
		WorkerTemplate = Server.AI.Actors.Worker,
		WorkerParent = game:GetService("ServerScriptService"),
		clock = os.clock,
		random = math.random,
		active = active,
		map = function(roundId, mapId)
			local maps = (resolve("MapService") :: unknown) :: Domain.MapService
			local context = maps:GetContext(roundId)
			local loop = (resolve("GameLoopService") :: unknown) :: Domain.GameLoopService
			local state = loop:GetState()
			local scenario = if state.Ok and state.Value.ScenarioId
				then Scenarios.ById[state.Value.ScenarioId]
				else nil
			if not context.Ok or not scenario or not Maps.ById[mapId] then
				return Result.failure("NotReady")
			end
			return Result.success({
				Context = context.Value,
				MapRate = Maps.ById[mapId].SpawnRate,
				ScenarioMultiplier = scenario.DroidMultiplier,
				EventMultiplier = 1,
			})
		end,
		ownerActive = function(userId, roundId)
			local state = players:Get(userId)
			return state.Ok and state.Value.State == "InRound" and state.Value.RoundId == roundId
		end,
		targets = function(roundId): { DroidAI.Target }
			local result: { DroidAI.Target } = {}
			local alive = players:GetAlive(roundId)
			if not alive.Ok then
				return result
			end
			for _, userId in alive.Value do
				local state = players:Get(userId)
				if state.Ok then
					playerChanged(state.Value)
				end
				local entity = registered[userId]
				local found = if entity then combat.World.resolve(entity) else nil
				local root = if entity then combat.World.root(entity) else nil
				if entity and found and found.Ok and root then
					table.insert(
						result,
						{
							Entity = entity,
							Position = { X = root.Position.X, Y = root.Position.Y, Z = root.Position.Z },
							Hp = found.Value.Hp,
							Faction = "Player" :: "Player",
						} :: DroidAI.Target
					)
				end
			end
			return result
		end,
		lastAttacker = function(entity)
			return attackers[identity(entity)]
		end,
		tuning = function()
			return nil
		end,
		combat = adapter.Port,
	})
	scope:add(runtime.destroy)
	services.DroidService, services.DroidBrainHost = runtime.Droids, runtime.Brains
	services.DamageService, services.StatService, services.StatusEffectService =
		combat.Damage, combat.Stats, combat.Status
	services.ProjectileService = adapter.Projectiles
	-- Public lifecycle teardown clears old attacker facts as well as the runtime's private rig ownership.
	local stopRound = runtime.Droids.StopRound
	runtime.Droids.StopRound = function(self: Service.Interface, roundId: number)
		local stopped = stopRound(self, roundId)
		if stopped.Ok then
			table.clear(attackers)
			attackerCount = 0
			adapter.clearRound(roundId)
		end
		return stopped
	end
	return table.freeze({ start = runtime.start, playerChanged = playerChanged, metrics = runtime.metrics })
end
return table.freeze(DroidPreview)
