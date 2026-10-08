--!strict
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Payloads = require(Shared.Contracts.Payloads)
local DroidAI = require(Shared.Contracts.DroidAI)
local Combat = require(Shared.Contracts.DroidCombat)
local Result = require(Shared.Contracts.Result)
local AIConfig = require(Shared.Config.AI)
local Config = require(Shared.Config.DroidRuntime)
local Types = require(script.Parent.DroidService.Types)
local Droids = require(script.Parent.DroidService.Implementation)
local Host = require(script.Parent.DroidBrainHost.Implementation)
local Steering = require(script.Parent.Parent.Parent.AI.Movement.Steering)
local Actuator = require(script.Parent.Parent.Parent.AI.Abilities.Actuator)
local Specs = require(script.Parent.Parent.Parent.AI.Abilities.Specs)
local Factions = require(script.Parent.FactionTargeting)
local Sync = require(script.Parent.DroidService.Sync)
export type Options = {
	Templates: Instance,
	Parent: Instance,
	Storage: Instance,
	WorkerTemplate: Script,
	WorkerParent: Instance,
	clock: () -> number,
	random: () -> number,
	map: (number, string) -> Result.Result<Types.Setup>,
	active: (number) -> boolean,
	ownerActive: (number, number) -> boolean,
	targets: (number) -> { DroidAI.Target },
	lastAttacker: ((Payloads.EntityRef) -> Payloads.EntityRef?)?,
	tuning: (string) -> Combat.Tuning?,
	combat: Combat.Port<Model>,
}
local DroidRuntime = {}
local function key(entity: Payloads.EntityRef): string
	return `{entity.RoundId}:{entity.Generation}:{entity.Id}`
end

--[=[ Explicit composition; one optional owned Heartbeat, serial sensing/actuation, bounded parallel decisions. ]=]
function DroidRuntime.new(options: Options)
	local raw = options
	options = table.clone(raw)
	options.clock = function()
		return Sync.call(raw.clock)
	end
	options.active = function(id)
		return Sync.call(function()
			return raw.active(id)
		end)
	end
	options.targets = function(id)
		return Sync.call(function()
			return raw.targets(id)
		end)
	end
	options.tuning = function(id)
		return Sync.call(function()
			return raw.tuning(id)
		end)
	end
	if raw.lastAttacker then
		local provider = raw.lastAttacker
		options.lastAttacker = function(entity)
			return Sync.call(function()
				return provider(entity)
			end)
		end
	end
	local brains = Host.new({
		clock = options.clock,
		workerTemplate = options.WorkerTemplate,
		parent = options.WorkerParent,
		Config = AIConfig,
	})
	local bodyById: { [string]: Types.Record } = {}
	local steering = Steering.new(options.clock, function(entity)
		local record = bodyById[key(entity)]
		return if record and record.Humanoid.Health > 0 then record else nil
	end)
	local actuator = Actuator.new(options.clock, options.active, options.combat, options.tuning)
	local droids = Droids.new({
		Templates = options.Templates,
		Parent = options.Parent,
		Storage = options.Storage,
		clock = options.clock,
		random = options.random,
		map = options.map,
		active = options.active,
		ownerActive = options.ownerActive,
		players = function(roundId)
			local positions = {}
			for _, target in options.targets(roundId) do
				if target.Faction == "Player" and target.Hp > 0 then
					table.insert(positions, target.Position)
				end
			end
			return positions
		end,
		register = function(record)
			return options.combat.register(
				record.Entity,
				record.Model,
				record.Faction,
				record.Definition.BulletImmune,
				record.OwnerUserId
			)
		end,
		unregister = function(entity)
			steering.remove(entity)
			actuator.remove(entity)
			bodyById[key(entity)] = nil
			options.combat.unregister(entity)
		end,
	})
	droids:Init()
	droids:Start()
	brains:Init()
	brains:Start()
	local destroyed, ticking = false, false
	local connection: RBXScriptConnection? = nil
	local sequence, roundId, frameAt, recoveryAt = 0, 0, -math.huge, -math.huge
	local frameTimes: { [number]: number } = {}
	local senseCursor, failures, retryAt, faulted = 1, 0, 0, false
	local function buildFrame(records: { Types.Record }, now: number): DroidAI.Frame
		local senseBegan = os.clock()
		sequence += 1
		local agents: { DroidAI.Agent } = {}
		local targets: { DroidAI.Target } = {}
		for _, target in options.targets(roundId) do
			if target.Entity.RoundId == roundId and target.Hp > 0 and #targets < AIConfig.MaxTargets then
				table.insert(targets, target)
			end
		end
		for _, target in droids.snapshots() do
			if target.Hp > 0 and #targets < AIConfig.MaxTargets then
				table.insert(targets, target)
			end
		end
		local pairs, sensed = 0, 0
		for offset = 0, #records - 1 do
			local record = records[(senseCursor + offset - 1) % #records + 1]
			bodyById[key(record.Entity)] = record
			local visible: { [string]: boolean } = {}
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { record.Model }
			for _, target in targets do
				if
					pairs >= AIConfig.MaxPairs
					or (os.clock() - senseBegan) * 1000 >= AIConfig.SenseBudgetMs
				then
					break
				end
				if not Factions.canTarget(record.Faction, target.Faction) then
					continue
				end
				local targetModel = options.combat.model(target.Entity)
				if targetModel then
					local position = Vector3.new(target.Position.X, target.Position.Y, target.Position.Z)
					local delta = position - record.Root.Position
					if delta.Magnitude > AIConfig.Policy.AcquireRange then
						continue
					end
					pairs += 1
					sensed = offset + 1
					local hit = workspace:Raycast(record.Root.Position, delta, params)
					visible[key(target.Entity)] = hit == nil or hit.Instance:IsDescendantOf(targetModel)
				end
			end
			local position = record.Root.Position
			table.insert(agents, {
				Entity = record.Entity,
				DefinitionId = record.Definition.Id,
				Position = { X = position.X, Y = position.Y, Z = position.Z },
				Hp = record.Humanoid.Health,
				Faction = record.Faction,
				Abilities = Specs.build(record.Definition, options.tuning(record.Definition.Id)),
				Visible = visible,
				LastAttacker = if options.lastAttacker then options.lastAttacker(record.Entity) else nil,
				StuckSeconds = steering.stuck(record.Entity),
			})
		end
		senseCursor = (senseCursor + math.max(sensed, 1) - 1) % #records + 1
		frameTimes[sequence] = now
		for id, time in frameTimes do
			if now - time > AIConfig.MaxDecisionAgeSeconds then
				frameTimes[id] = nil
			end
		end
		return {
			Version = 1,
			RoundId = roundId,
			Sequence = sequence,
			Now = now,
			Agents = agents,
			Targets = targets,
			Config = AIConfig.Policy,
		}
	end
	local function step()
		if destroyed or ticking or faulted or os.clock() < retryAt then
			return
		end
		ticking = true
		local ok = pcall(function()
			local now = options.clock()
			if now - recoveryAt >= Config.RecoveryIntervalSeconds then
				droids.step()
				recoveryAt = now
			end
			actuator.step()
			steering.step()
			local records = droids.records()
			if #records == 0 then
				return
			end
			local currentRound = records[1].Entity.RoundId
			if roundId ~= currentRound then
				if roundId ~= 0 then
					brains:StopRound(roundId)
					steering.clearRound(roundId)
				end
				roundId, frameAt = currentRound, -math.huge
				table.clear(frameTimes)
			end
			local decisions = brains:CollectDecisions(roundId)
			if decisions.Ok then
				for _, decision in decisions.Value do
					local record = bodyById[key(decision.Entity)]
					local began = frameTimes[decision.SnapshotSequence]
					if
						not record
						or not began
						or now - began > AIConfig.MaxDecisionAgeSeconds
						or not options.active(roundId)
					then
						continue
					end
					if decision.Action == "Move" or decision.Action == "Repath" then
						if decision.Position and not actuator.locked(record.Entity) then
							local goal = decision.Position
							local target = if decision.Target
								then options.combat.model(decision.Target)
								else nil
							local targetHumanoid = if target
								then target:FindFirstChildOfClass("Humanoid")
								else nil
							if decision.Target and (not targetHumanoid or targetHumanoid.Health <= 0) then
								continue
							end
							local params = RaycastParams.new()
							params.FilterType = Enum.RaycastFilterType.Exclude
							params.FilterDescendantsInstances = { record.Model }
							local position = Vector3.new(goal.X, goal.Y, goal.Z)
							local obstruction = workspace:Raycast(
								record.Root.Position,
								position - record.Root.Position,
								params
							)
							local visible = obstruction == nil
								or (target ~= nil and obstruction.Instance:IsDescendantOf(target))
							steering.move(record.Entity, position, visible)
						end
					elseif decision.Action == "Jump" then
						if not actuator.locked(record.Entity) then
							record.Humanoid.Jump = true
						end
					else
						actuator.apply(record, decision, decision.SnapshotSequence)
					end
				end
			end
			if now - frameAt >= AIConfig.NearIntervalSeconds then
				local configured = brains.configureFrame(buildFrame(records, now))
				assert(configured.Ok, "Droid snapshot rejected")
				frameAt = now
			end
			local scheduled = brains:Schedule(roundId, AIConfig.FrameBudgetMs)
			assert(scheduled.Ok, "Droid schedule rejected")
			return true
		end)
		ticking = false
		if not ok then
			failures += 1
			retryAt = os.clock() + AIConfig.FailureBackoffSeconds
			warn("Droid runtime tick failed; bounded recovery scheduled")
			if failures >= AIConfig.MaxTickFailures then
				faulted = true
				if connection then
					connection:Disconnect()
					connection = nil
				end
				pcall(function()
					droids:Stop()
				end)
				pcall(function()
					brains:Stop()
				end)
				steering.clearRound(roundId)
			end
		else
			failures = 0
		end
	end
	local stopDroids = droids.StopRound
	local function clearRound(expected: number): Result.Result<boolean>
		if roundId ~= 0 and expected ~= roundId then
			return Result.failure("StaleRound")
		end
		local stopped = stopDroids(droids, expected)
		if not stopped.Ok then
			return stopped
		end
		local cleared = brains:StopRound(expected)
		steering.clearRound(expected)
		table.clear(frameTimes)
		roundId, frameAt = 0, -math.huge
		return if not stopped.Ok then stopped elseif not cleared.Ok then cleared else Result.success(true)
	end
	droids.StopRound = function(_self, expected: number): Result.Result<boolean>
		return clearRound(expected)
	end
	return table.freeze({
		Droids = droids,
		Brains = brains,
		step = step,
		clearRound = clearRound,
		start = function()
			if not destroyed and not connection then
				connection = RunService.Heartbeat:Connect(step)
			end
		end,
		metrics = function()
			return {
				Lifecycle = droids.metrics(),
				AI = brains.metrics(),
				Paths = steering.metrics(),
				Heartbeats = if connection then 1 else 0,
				Faulted = faulted,
			}
		end,
		destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			if connection then
				connection:Disconnect()
				connection = nil
			end
			pcall(function()
				droids:Destroy()
			end)
			pcall(function()
				brains:Destroy()
			end)
			pcall(actuator.destroy)
			pcall(steering.destroy)
			table.clear(bodyById)
			table.clear(frameTimes)
		end,
	})
end
return table.freeze(DroidRuntime)
