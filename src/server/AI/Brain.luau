--!strict
local DroidAI = require("@game/ReplicatedStorage/Shared/Contracts/DroidAI")
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Tree = require("./BehaviorTree")
local TargetScoring = require("./Perception/TargetScoring")

export type Api = {
	decide: (DroidAI.Frame, string) -> Result.Result<Payloads.BrainDecision>,
	remove: (Payloads.EntityRef) -> (),
	clearRound: (number) -> (),
	destroy: () -> (),
}
type Record = {
	Entity: Payloads.EntityRef,
	Tree: Tree.Node,
	Blackboard: { [string]: unknown },
	LastNow: number,
	LastSequence: number,
}
type Tick = {
	Frame: DroidAI.Frame,
	Agent: DroidAI.Agent,
	Target: DroidAI.Target?,
	Decision: Payloads.BrainDecision,
}

local Brain = {}
local ACTIONS: { [string]: string } = table.freeze({
	melee = "Melee",
	lunge = "Lunge",
	shoot = "Shoot",
	throw_paper = "ThrowPaper",
	shock_gun = "ShockGun",
})

local function finite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function positive(value: number?): boolean
	return value ~= nil and finite(value) and value > 0
end

local function emit(data: Tick, action: string)
	data.Decision.Action = action
	if data.Target then
		data.Decision.Target = data.Target.Entity
		data.Decision.Position = data.Target.Position
	end
end

local function attack(ability: DroidAI.Ability): Tree.Node?
	local action = ACTIONS[ability.Id]
	if action == nil or not positive(ability.Range) or not positive(ability.CooldownSeconds) then
		return nil
	end
	local range = ability.Range :: number
	return Tree.Sequence({
		Tree.Condition(function(context)
			local data = context.Data :: Tick
			local target = data.Target
			return target ~= nil
				and data.Agent.Visible[TargetScoring.key(target.Entity)] == true
				and TargetScoring.distanceSquared(data.Agent.Position, target.Position) <= range * range
		end),
		Tree.Cooldown(
			ability.CooldownSeconds :: number,
			Tree.Action(function(context)
				local data = context.Data :: Tick
				emit(data, action)
				if action == "Lunge" and positive(ability.RecoverySeconds) then
					context.Blackboard.recoveryUntil = context.Now + (ability.RecoverySeconds :: number)
				end
				return "Success"
			end)
		),
	})
end

local function build(agent: DroidAI.Agent): Tree.Node
	local nodes: { Tree.Node } = {
		Tree.Sequence({
			Tree.Condition(function(context)
				local recovery = context.Blackboard.recoveryUntil
				return type(recovery) == "number" and context.Now < recovery
			end),
			Tree.Action(function(context)
				emit(context.Data :: Tick, "SitRecover")
				return "Success"
			end),
		}),
	}
	-- Specials take precedence over a melee attack in overlapping ranges.
	for _, ability in agent.Abilities do
		if ability.Id ~= "melee" then
			local node = attack(ability)
			if node then
				table.insert(nodes, node)
			end
		end
	end
	for _, ability in agent.Abilities do
		if ability.Id == "melee" then
			local node = attack(ability)
			if node then
				table.insert(nodes, node)
			end
		end
	end
	table.insert(
		nodes,
		Tree.Action(function(context)
			local data = context.Data :: Tick
			if data.Target == nil then
				emit(data, "Idle")
			elseif
				data.Agent.StuckSeconds >= data.Frame.Config.StuckRepathSeconds
				or not data.Agent.Visible[TargetScoring.key(data.Target.Entity)]
			then
				emit(data, "Repath")
			elseif data.Agent.StuckSeconds >= data.Frame.Config.StuckJumpSeconds then
				emit(data, "Jump")
			else
				emit(data, "Move")
			end
			return "Success"
		end)
	)
	return Tree.Selector(nodes)
end

local function validFrame(frame: DroidAI.Frame): boolean
	local policy = frame.Config
	return frame.Version == DroidAI.Version
		and finite(frame.Now)
		and frame.Now >= 0
		and frame.Sequence % 1 == 0
		and frame.Sequence > 0
		and #frame.Agents <= policy.MaxAgents
		and #frame.Targets <= policy.MaxTargets
		and finite(policy.AcquireRange)
		and policy.AcquireRange > 0
		and finite(policy.DistanceWeight)
		and policy.DistanceWeight >= 0
		and finite(policy.LastAttackerBonus)
		and finite(policy.StructureBonus)
		and finite(policy.StuckJumpSeconds)
		and policy.StuckJumpSeconds > 0
		and finite(policy.StuckRepathSeconds)
		and policy.StuckRepathSeconds >= policy.StuckJumpSeconds
end

--[=[ One blackboard per round/generation/entity; the same tree instance is never shared between agents. ]=]
function Brain.new(): Api
	local records: { [string]: Record } = {}
	local count = 0
	local closed = false
	local function remove(entity: Payloads.EntityRef)
		local id = TargetScoring.key(entity)
		local record = records[id]
		if record then
			record.Tree.cancel({
				Now = record.LastNow,
				Blackboard = record.Blackboard,
				Data = nil,
				Cancelled = true,
			})
			table.clear(record.Blackboard)
			records[id] = nil
			count -= 1
		end
	end
	return table.freeze({
		decide = function(frame: DroidAI.Frame, selfId: string): Result.Result<Payloads.BrainDecision>
			if closed then
				return Result.failure("Unavailable")
			end
			if not validFrame(frame) then
				return Result.failure("InvalidRequest")
			end
			local agent: DroidAI.Agent? = nil
			for _, candidate in frame.Agents do
				if candidate.Entity.Id == selfId then
					if agent ~= nil then
						return Result.failure("InvalidRequest")
					end
					agent = candidate
				end
			end
			if agent == nil then
				return Result.failure("UnknownId")
			end
			if agent.Entity.RoundId ~= frame.RoundId or agent.Hp <= 0 then
				return Result.failure("StaleRound")
			end
			local id = TargetScoring.key(agent.Entity)
			local record = records[id]
			if record == nil then
				if count >= frame.Config.MaxAgents then
					return Result.failure("LimitReached")
				end
				record = {
					Entity = table.clone(agent.Entity),
					Tree = build(agent),
					Blackboard = {},
					LastNow = 0,
					LastSequence = 0,
				}
				records[id] = record
				count += 1
			end
			if frame.Now < record.LastNow or frame.Sequence <= record.LastSequence then
				return Result.failure("StaleRound")
			end
			record.LastNow, record.LastSequence = frame.Now, frame.Sequence
			local decision: Payloads.BrainDecision =
				{ Entity = agent.Entity, SnapshotSequence = frame.Sequence, Action = "Idle" }
			local data: Tick = {
				Frame = frame,
				Agent = agent,
				Target = TargetScoring.choose(agent, frame.Targets, frame.Config),
				Decision = decision,
			}
			local status = record.Tree.tick({ Now = frame.Now, Blackboard = record.Blackboard, Data = data })
			if status == "Failure" then
				return Result.failure("Unavailable")
			end
			return Result.success(table.freeze(decision))
		end,
		remove = remove,
		clearRound = function(roundId: number)
			for _, record in records do
				if record.Entity.RoundId == roundId then
					remove(record.Entity)
				end
			end
		end,
		destroy = function()
			if closed then
				return
			end
			closed = true
			for _, record in records do
				remove(record.Entity)
			end
		end,
	})
end

return table.freeze(Brain)
