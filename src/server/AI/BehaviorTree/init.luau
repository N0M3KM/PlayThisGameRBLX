--!strict
--[=[ Pure behavior-tree nodes. Mutable execution state belongs to the caller's blackboard. ]=]
export type Status = "Success" | "Failure" | "Running"
export type Context = {
	Now: number,
	Blackboard: { [string]: unknown },
	Data: unknown,
	Cancelled: boolean?,
}
export type Node = {
	tick: (Context) -> Status,
	cancel: (Context) -> (),
}

local BehaviorTree = {}
local nextNodeId = 0

local function key(): string
	nextNodeId += 1
	return "bt_" .. tostring(nextNodeId)
end

local function invoke(callback: (Context) -> unknown, context: Context): unknown
	local thread = coroutine.create(callback)
	local ok, value = coroutine.resume(thread, context)
	if coroutine.status(thread) ~= "dead" then
		coroutine.close(thread)
		return nil
	end
	return if ok then value else nil
end

local function cancel(node: Node, context: Context)
	invoke(node.cancel, context)
end

local function tick(node: Node, context: Context): Status
	local status = invoke(node.tick, context)
	if status == "Success" or status == "Running" or status == "Failure" then
		return status
	end
	cancel(node, context)
	return "Failure"
end

--[=[ Isolates throwing/yielding callbacks. Actions must be synchronous and side-effect free. ]=]
function BehaviorTree.Action(callback: (Context) -> Status, onCancel: ((Context) -> ())?): Node
	return table.freeze({
		tick = function(context: Context): Status
			if context.Cancelled then
				if onCancel then
					invoke(onCancel, context)
				end
				return "Failure"
			end
			local value = invoke(callback, context)
			if value == "Success" or value == "Running" then
				return value
			end
			if value ~= "Failure" and onCancel then
				invoke(onCancel, context)
			end
			return "Failure"
		end,
		cancel = function(context: Context)
			if onCancel then
				invoke(onCancel, context)
			end
		end,
	})
end

function BehaviorTree.Condition(predicate: (Context) -> boolean): Node
	return BehaviorTree.Action(function(context)
		return if invoke(predicate, context) == true then "Success" else "Failure"
	end)
end

local function composite(children: { Node }, selector: boolean): Node
	local nodes = table.clone(children)
	local runningKey = key()
	return table.freeze({
		tick = function(context: Context): Status
			local previous = context.Blackboard[runningKey]
			if context.Cancelled then
				for _, child in nodes do
					cancel(child, context)
				end
				context.Blackboard[runningKey] = nil
				return "Failure"
			end
			for index, child in nodes do
				local status = tick(child, context)
				if
					status == "Running"
					or (selector and status == "Success")
					or (not selector and status == "Failure")
				then
					if type(previous) == "number" and previous ~= index and nodes[previous] then
						cancel(nodes[previous], context)
					end
					context.Blackboard[runningKey] = if status == "Running" then index else nil
					return status
				end
			end
			if type(previous) == "number" and nodes[previous] then
				cancel(nodes[previous], context)
			end
			context.Blackboard[runningKey] = nil
			return if selector then "Failure" else "Success"
		end,
		cancel = function(context: Context)
			for _, child in nodes do
				cancel(child, context)
			end
			context.Blackboard[runningKey] = nil
		end,
	})
end

function BehaviorTree.Selector(children: { Node }): Node
	return composite(children, true)
end

function BehaviorTree.Sequence(children: { Node }): Node
	return composite(children, false)
end

function BehaviorTree.Cooldown(seconds: number, child: Node): Node
	assert(seconds == seconds and seconds >= 0 and seconds < math.huge, "Finite cooldown required")
	local readyKey = key()
	return table.freeze({
		tick = function(context: Context): Status
			if context.Cancelled then
				cancel(child, context)
				return "Failure"
			end
			local ready = context.Blackboard[readyKey]
			if type(ready) == "number" and context.Now < ready then
				return "Failure"
			end
			local status: Status = tick(child, context)
			if status == "Success" then
				context.Blackboard[readyKey] = context.Now + seconds
			end
			return status
		end,
		cancel = function(context: Context)
			cancel(child, context)
		end,
	})
end

return table.freeze(BehaviorTree)
