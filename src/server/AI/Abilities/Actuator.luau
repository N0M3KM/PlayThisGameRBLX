--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Players = game:GetService("Players")
local Payloads = require(Shared.Contracts.Payloads)
local Combat = require(Shared.Contracts.DroidCombat)
local Result = require(Shared.Contracts.Result)
local AI = require(Shared.Contracts.DroidAI)
local Validation = require(Shared.Registry.Validation)
local RuntimeConfig = require(Shared.Config.DroidRuntime)
local Records = require(script.Parent.Parent.Parent.Services.Droids.DroidService.Types)
local Sync = require(script.Parent.Parent.Parent.Services.Droids.DroidService.Sync)
local Factions = require(script.Parent.Parent.Parent.Services.Droids.FactionTargeting)
local Specs = require(script.Parent.Specs)
export type Api = {
	apply: (Records.Record, Payloads.BrainDecision, number) -> Result.Result<boolean>,
	locked: (Payloads.EntityRef) -> boolean,
	step: () -> (),
	remove: (Payloads.EntityRef) -> (),
	destroy: () -> (),
}
type Lunge = {
	Target: Payloads.EntityRef,
	ExpiresAt: number,
	Ability: AI.Ability,
	Tuning: Combat.Tuning,
}
type State = {
	Entity: Payloads.EntityRef,
	Record: Records.Record,
	Ready: { [string]: number },
	RecoverAt: number?,
	Lunge: Lunge?,
	OwnsSit: boolean,
	SourceId: string,
}
type Target = { Model: Model, Root: BasePart, Delta: Vector3 }
local Actuator = {}
local ACTIONS: { [string]: string } = table.freeze({
	Melee = "melee",
	Lunge = "lunge",
	Shoot = "shoot",
	ThrowPaper = "throw_paper",
	ShockGun = "shock_gun",
})
local function key(entity: Payloads.EntityRef): string
	return `{entity.RoundId}:{entity.Generation}:{entity.Id}`
end
local function point(vector: Vector3): Payloads.Point
	return { X = vector.X, Y = vector.Y, Z = vector.Z }
end
local function positive(value: number?): boolean
	return value ~= nil and Validation.finite(value) and value > 0
end

--[=[ Worker intents are revalidated serially. Movement is a source-owned C modifier, never a saved speed restore. ]=]
function Actuator.new(
	clock: () -> number,
	active: (number) -> boolean,
	port: Combat.Port<Model>,
	tuning: (string) -> Combat.Tuning?
): Api
	local states: { [string]: State } = {}
	local busy: { [string]: boolean } = {}
	local destroyed, shots = false, 0
	local function now(): number
		local value = Sync.call(clock)
		assert(Validation.finite(value) and value >= 0, "Invalid actuator clock")
		return value
	end
	local function controlLocked(entity: Payloads.EntityRef): boolean
		return Sync.call(function()
			return port.controlLocked(entity)
		end)
	end
	local function model(entity: Payloads.EntityRef): Model?
		return Sync.call(function()
			return port.model(entity)
		end)
	end
	local function refresh(entity: Payloads.EntityRef)
		Sync.run(function()
			port.refresh(entity)
		end)
	end
	local function current(record: Records.Record): boolean
		return not destroyed
			and Sync.call(function()
				return active(record.Entity.RoundId)
			end)
			and model(record.Entity) == record.Model
			and record.Model:IsDescendantOf(workspace)
			and record.Root:IsDescendantOf(record.Model)
			and record.Humanoid.Parent == record.Model
			and record.Humanoid.Health > 0
	end
	local function target(
		record: Records.Record,
		entity: Payloads.EntityRef,
		range: number
	): Result.Result<Target>
		if
			not current(record)
			or controlLocked(record.Entity)
			or entity.RoundId ~= record.Entity.RoundId
			or key(entity) == key(record.Entity)
		then
			return Result.failure("StaleRound")
		end
		local targetModel = model(entity)
		local humanoid = if targetModel then targetModel:FindFirstChildOfClass("Humanoid") else nil
		local root = if targetModel then targetModel:FindFirstChild("HumanoidRootPart") else nil
		if
			not targetModel
			or not targetModel:IsDescendantOf(workspace)
			or not humanoid
			or humanoid.Health <= 0
			or not root
			or not root:IsA("BasePart")
		then
			return Result.failure("StaleRound")
		end
		local faction = if Players:GetPlayerFromCharacter(targetModel)
			then "Player"
			else targetModel:GetAttribute("Faction")
		if faction ~= "Player" and faction ~= "Allied" and faction ~= "Hostile" then
			return Result.failure("InvalidRequest")
		end
		if not Factions.canTarget(record.Faction, faction) then
			return Result.failure("WrongState")
		end
		local delta = root.Position - record.Root.Position
		if not Validation.finite(delta.Magnitude) or delta.Magnitude > range or delta.Magnitude == 0 then
			return Result.failure("InvalidRequest")
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { record.Model }
		local hit = workspace:Raycast(record.Root.Position, delta, params)
		if hit and not hit.Instance:IsDescendantOf(targetModel) then
			return Result.failure("InvalidRequest")
		end
		return Result.success({ Model = targetModel, Root = root, Delta = delta })
	end
	local function clearMovement(state: State)
		Sync.call(function()
			return port.stats:RemoveSource(state.Entity, state.SourceId)
		end)
		local humanoid = state.Record.Humanoid
		if state.OwnsSit and humanoid.Parent and model(state.Entity) == state.Record.Model then
			humanoid.Sit = false
		end
		state.OwnsSit = false
		refresh(state.Entity)
	end
	local function remove(entity: Payloads.EntityRef)
		local identity = key(entity)
		local state = states[identity]
		states[identity] = nil
		if state then
			pcall(clearMovement, state)
		end
	end
	local function movement(state: State, factor: number): Result.Result<boolean>
		local added = Sync.call(function()
			return port.stats:Add(
				state.Entity,
				{ SourceId = state.SourceId, Stat = "WalkSpeed", Mode = "Multiply", Value = factor }
			)
		end)
		if added.Ok then
			refresh(state.Entity)
		end
		return added
	end
	local function recover(state: State, time: number)
		if state.RecoverAt and time >= state.RecoverAt then
			state.RecoverAt = nil
			clearMovement(state)
		end
	end
	local function endLunge(state: State, time: number, recovery: number)
		state.Lunge = nil
		clearMovement(state)
		if not current(state.Record) or controlLocked(state.Entity) then
			return
		end
		local stopped = movement(state, 0)
		assert(stopped.Ok, "Recovery modifier unavailable")
		state.RecoverAt = time + recovery
		if not state.Record.Humanoid.Sit then
			state.OwnsSit = true
			state.Record.Humanoid.Sit = true
		end
	end
	local function stepLunge(state: State, time: number)
		local lunge = state.Lunge
		if not lunge then
			return
		end
		if not current(state.Record) or controlLocked(state.Entity) then
			state.Lunge = nil
			clearMovement(state)
			return
		end
		-- Contact gets a fresh identity, alive, faction, distance and LOS check.
		local contact = target(state.Record, lunge.Target, RuntimeConfig.MeleeRange)
		if contact.Ok then
			local hit = Sync.call(function()
				return port.damage:Apply({
					Source = state.Entity,
					Target = lunge.Target,
					Amount = lunge.Ability.Damage :: number,
					Faction = state.Record.Faction,
					Kind = "Ability",
				})
			end)
			if hit.Ok and hit.Value.ActualHpLoss > 0 then
				Sync.call(function()
					return port.status:Apply(
						lunge.Target,
						"stun",
						`lunge_{state.Entity.Id}`,
						lunge.Tuning.LungeStunSeconds :: number
					)
				end)
				Sync.call(function()
					return port.status:Apply(
						lunge.Target,
						"ragdoll",
						`lunge_ragdoll_{state.Entity.Id}`,
						lunge.Tuning.LungeRagdollSeconds :: number
					)
				end)
			end
			endLunge(state, time, lunge.Ability.RecoverySeconds :: number)
		elseif time >= lunge.ExpiresAt or contact.Code == "StaleRound" or contact.Code == "WrongState" then
			endLunge(state, time, lunge.Ability.RecoverySeconds :: number)
		end
	end
	local function apply(
		record: Records.Record,
		decision: Payloads.BrainDecision,
		latestSequence: number
	): Result.Result<boolean>
		if
			not current(record)
			or decision.SnapshotSequence ~= latestSequence
			or not decision.Target
			or key(decision.Entity) ~= key(record.Entity)
		then
			return Result.failure("StaleRound")
		end
		if controlLocked(record.Entity) then
			return Result.failure("WrongState")
		end
		local time, identity = now(), key(record.Entity)
		local state = states[identity]
		if not state then
			state = {
				Entity = table.freeze(table.clone(record.Entity)),
				Record = record,
				Ready = {},
				OwnsSit = false,
				SourceId = `droid_move_{record.Entity.Id}_{record.Entity.Generation}`,
			}
			states[identity] = state
		end
		recover(state, time)
		if state.RecoverAt or state.Lunge then
			return Result.failure("WrongState")
		end
		local abilityId = ACTIONS[decision.Action]
		if not abilityId then
			return Result.failure("InvalidRequest")
		end
		local values: Combat.Tuning = Sync.call(function()
			return tuning(record.Definition.Id)
		end) or {}
		local ability: AI.Ability? = nil
		for _, candidate in Specs.build(record.Definition, values) do
			if candidate.Id == abilityId then
				ability = candidate
			end
		end
		if not ability or not positive(ability.Range) or not positive(ability.CooldownSeconds) then
			return Result.failure("NotReady")
		end
		if time < (state.Ready[abilityId] or 0) then
			return Result.failure("Cooldown")
		end
		local targetRef = decision.Target
		local checked = target(record, targetRef, ability.Range :: number)
		if not checked.Ok then
			return Result.failure(checked.Code)
		end
		local resolved = checked.Value
		if
			abilityId == "lunge"
			and (
				not positive(values.LungeStunSeconds)
				or not positive(values.LungeRagdollSeconds)
				or not positive(values.LungeSpeed)
				or not positive(ability.RecoverySeconds)
			)
		then
			return Result.failure("NotReady")
		end
		if abilityId ~= "shock_gun" and not positive(ability.Damage) then
			return Result.failure("NotReady")
		end
		if abilityId == "shock_gun" and not positive(ability.DurationSeconds) then
			return Result.failure("NotReady")
		end
		if abilityId == "shoot" or abilityId == "throw_paper" then
			local projectile = port.projectile
			if not projectile or not positive(values.ProjectileSpeed) then
				return Result.failure("NotReady")
			end
			state.Ready[abilityId] = time + (ability.CooldownSeconds :: number)
			shots += 1
			return Sync.call(function()
				return projectile({
					Source = record.Entity,
					Target = targetRef,
					Origin = point(record.Root.Position),
					Direction = point(resolved.Delta.Unit),
					Damage = ability.Damage :: number,
					Speed = values.ProjectileSpeed :: number,
					Range = ability.Range :: number,
					ShotId = `droid_shot_{shots}`,
					Kind = if abilityId == "shoot" then "Bullet" else "Paper",
				})
			end)
		end
		if abilityId == "lunge" then
			local changed = movement(state, (values.LungeSpeed :: number) / RuntimeConfig.WalkSpeed)
			if not changed.Ok then
				return changed
			end
			if
				not current(record)
				or controlLocked(record.Entity)
				or not positive(record.Humanoid.WalkSpeed)
			then
				clearMovement(state)
				return Result.failure("WrongState")
			end
			state.Ready[abilityId] = time + (ability.CooldownSeconds :: number)
			state.Lunge = {
				Target = targetRef,
				ExpiresAt = time + (ability.Range :: number) / record.Humanoid.WalkSpeed,
				Ability = ability,
				Tuning = table.freeze(table.clone(values)),
			}
			record.Humanoid:MoveTo(resolved.Root.Position)
			return Result.success(true)
		end
		state.Ready[abilityId] = time + (ability.CooldownSeconds :: number)
		if abilityId == "shock_gun" then
			return Sync.call(function()
				return port.status:Apply(
					targetRef,
					"stun",
					`shock_{record.Entity.Id}`,
					ability.DurationSeconds :: number
				)
			end)
		end
		local applied = Sync.call(function()
			return port.damage:Apply({
				Source = record.Entity,
				Target = targetRef,
				Amount = ability.Damage :: number,
				Faction = record.Faction,
				Kind = if abilityId == "melee" then "Melee" else "Ability",
			})
		end)
		return if applied.Ok then Result.success(true) else Result.failure(applied.Code)
	end
	return table.freeze({
		apply = function(
			record: Records.Record,
			decision: Payloads.BrainDecision,
			latestSequence: number
		): Result.Result<boolean>
			local identity = key(record.Entity)
			if busy[identity] then
				return Result.failure("WrongState")
			end
			busy[identity] = true
			local ok, result = pcall(apply, record, decision, latestSequence)
			busy[identity] = nil
			if not ok then
				remove(record.Entity)
				return Result.failure("Unavailable")
			end
			return result
		end,
		locked = function(entity: Payloads.EntityRef): boolean
			local ok, locked = pcall(function()
				if controlLocked(entity) then
					return true
				end
				local state = states[key(entity)]
				if state then
					recover(state, now())
				end
				return state ~= nil and (state.RecoverAt ~= nil or state.Lunge ~= nil)
			end)
			return not ok or locked
		end,
		step = function()
			for identity, state in states do
				if not busy[identity] then
					busy[identity] = true
					local ok = pcall(function()
						local time = now()
						stepLunge(state, time)
						recover(state, time)
					end)
					busy[identity] = nil
					if not ok then
						remove(state.Entity)
					end
				end
			end
		end,
		remove = remove,
		destroy = function()
			destroyed = true
			for _, state in states do
				remove(state.Entity)
			end
			table.clear(states)
		end,
	})
end
return table.freeze(Actuator)
