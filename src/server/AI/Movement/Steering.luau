--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Payloads = require(Shared.Contracts.Payloads)
local Config = require(Shared.Config.DroidRuntime)
local Paths = require(script.Parent.PathQueue)
export type Body = { Model: Model, Humanoid: Humanoid, Root: BasePart }
export type Api = {
	move: (Payloads.EntityRef, Vector3, boolean) -> (),
	stuck: (Payloads.EntityRef) -> number,
	remove: (Payloads.EntityRef) -> (),
	clearRound: (number) -> (),
	step: () -> (),
	metrics: () -> { Pending: number, Active: number },
	destroy: () -> (),
}
type State = {
	Entity: Payloads.EntityRef,
	Position: Vector3,
	UpdatedAt: number,
	StuckAt: number,
	PathAt: number,
	Goal: Vector3?,
	Epoch: number,
	Waypoints: { PathWaypoint }?,
	Waypoint: number,
}
local Steering = {}
local function key(entity: Payloads.EntityRef): string
	return `{entity.RoundId}:{entity.Generation}:{entity.Id}`
end

--[=[ LOS chase is immediate; obstructed targets share a bounded serial path queue. ]=]
function Steering.new(clock: () -> number, body: (Payloads.EntityRef) -> Body?): Api
	local states: { [string]: State } = {}
	local queue = Paths.new(clock)
	local destroyed = false
	local function remove(entity: Payloads.EntityRef)
		local identity = key(entity)
		queue.remove(identity)
		states[identity] = nil
	end
	return table.freeze({
		move = function(entity: Payloads.EntityRef, target: Vector3, visible: boolean)
			local current = body(entity)
			if destroyed or not current or current.Humanoid.Health <= 0 then
				return
			end
			local identity, now = key(entity), clock()
			local state = states[identity]
			if not state then
				state = {
					Entity = entity,
					Position = current.Root.Position,
					UpdatedAt = now,
					StuckAt = now,
					PathAt = -math.huge,
					Epoch = 0,
					Waypoint = 1,
				}
				states[identity] = state
			end
			if (current.Root.Position - state.Position).Magnitude >= Config.MovementEpsilon then
				state.StuckAt = now
			end
			state.Position, state.UpdatedAt = current.Root.Position, now
			if visible then
				state.Epoch += 1
				state.Waypoints = nil
				queue.remove(identity)
				current.Humanoid:MoveTo(target)
				return
			end
			if state.Waypoints and now - state.PathAt <= Config.PathCacheSeconds then
				local waypoint = state.Waypoints[state.Waypoint]
				if
					waypoint
					and (current.Root.Position - waypoint.Position).Magnitude <= Config.WaypointTolerance
				then
					state.Waypoint += 1
					waypoint = state.Waypoints[state.Waypoint]
				end
				if waypoint then
					current.Humanoid.Jump = waypoint.Action == Enum.PathWaypointAction.Jump
					current.Humanoid:MoveTo(waypoint.Position)
					return
				end
			end
			if now - state.PathAt < Config.PathRepathSeconds then
				return
			end
			state.PathAt, state.Goal = now, target
			state.Epoch += 1
			local epoch = state.Epoch
			queue.request(identity, current.Root.Position, target, function()
				return not destroyed
					and states[identity] == state
					and state.Epoch == epoch
					and body(entity) ~= nil
			end, function(result)
				if result.Ok then
					state.Waypoints, state.Waypoint = result.Value, 2
				else
					state.Waypoints = nil
				end
			end)
		end,
		stuck = function(entity: Payloads.EntityRef)
			local state = states[key(entity)]
			return if state then math.max(0, clock() - state.StuckAt) else 0
		end,
		remove = remove,
		clearRound = function(roundId: number)
			for _, state in states do
				if state.Entity.RoundId == roundId then
					remove(state.Entity)
				end
			end
		end,
		step = queue.step,
		metrics = queue.metrics,
		destroy = function()
			destroyed = true
			queue.destroy()
			table.clear(states)
		end,
	})
end
return table.freeze(Steering)
