--!strict
-- Injected in-memory test transport. This is not ReplicaService or a live replication implementation.
local Schemas = require("../../src/shared/Contracts/SnapshotSchemas")
local Payloads = require("../../src/shared/Contracts/Payloads")
local Result = require("../../src/shared/Contracts/Result")
local SnapshotBinding = require("../../src/shared/Framework/SnapshotBinding")
local Fixture = {}
type Listener = { Callback: (unknown) -> (), Active: boolean }
type Channel<T> = {
	publish: (string, T) -> (),
	subscribe: (string, (unknown) -> ()) -> () -> (),
	remove: (string) -> (),
	count: () -> number,
	destroy: () -> (),
}
local function channel<T>(): Channel<T>
	local listeners: { [string]: { [number]: Listener } } = {}
	local snapshots: { [string]: T } = {}
	local nextId, count = 0, 0
	local destroyed = false
	local function remove(key: string)
		local audience = listeners[key]
		if audience then
			for _, listener in audience do
				listener.Active = false
				count -= 1
			end
		end
		listeners[key], snapshots[key] = nil, nil
	end
	return {
		publish = function(key: string, snapshot: T)
			assert(not destroyed, "Fixture is destroyed")
			snapshots[key] = snapshot
			local audience: { [number]: Listener } = listeners[key] or {}
			local pending: { Listener } = {}
			for _, listener in audience do
				table.insert(pending, listener)
			end
			for _, listener in pending do
				if listener.Active then
					pcall(listener.Callback, snapshot)
				end
			end
		end,
		subscribe = function(key: string, callback: (unknown) -> ()): () -> ()
			assert(not destroyed, "Fixture is destroyed")
			nextId += 1
			local id = nextId
			local listener = { Callback = callback, Active = true }
			local audience: { [number]: Listener } = listeners[key] or {}
			listeners[key] = audience
			audience[id] = listener
			count += 1
			local function disconnect()
				if listener.Active then
					listener.Active = false
					audience[id] = nil
					count -= 1
				end
			end
			if snapshots[key] ~= nil then
				local notified = table.pack(pcall(callback, snapshots[key]))
				if not notified[1] then
					disconnect()
					error(tostring(notified[2]), 0)
				end
			end
			return disconnect
		end,
		remove = remove,
		count = function(): number
			return count
		end,
		destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			for key in listeners do
				remove(key)
			end
			table.clear(snapshots)
		end,
	}
end

export type Replica = {
	matchSubscription: SnapshotBinding.Subscribe,
	privateSubscription: (number) -> SnapshotBinding.Subscribe,
	publishMatch: (unknown) -> Result.Result<boolean>,
	publishPrivate: (number, unknown) -> Result.Result<boolean>,
	removeUser: (number) -> (),
	count: () -> number,
	destroy: () -> (),
}
function Fixture.new(): Replica
	local public: Channel<Payloads.MatchSnapshot> = channel()
	local private: Channel<Payloads.PlayerDataSnapshot> = channel()
	return {
		matchSubscription = function(callback: (unknown) -> ())
			return public.subscribe("match", callback)
		end,
		privateSubscription = function(userId: number): SnapshotBinding.Subscribe
			return function(callback: (unknown) -> ())
				return private.subscribe(tostring(userId), callback)
			end
		end,
		publishMatch = function(value: unknown): Result.Result<boolean>
			local validated = Schemas.match(value)
			if not validated.Ok then
				return Result.failure(validated.Code)
			end
			public.publish("match", validated.Value)
			return Result.success(true)
		end,
		publishPrivate = function(userId: number, value: unknown): Result.Result<boolean>
			local validated = Schemas.player(value)
			if not validated.Ok then
				return Result.failure(validated.Code)
			end
			if validated.Value.UserId ~= userId then
				return Result.failure("InvalidRequest")
			end
			private.publish(tostring(userId), validated.Value)
			return Result.success(true)
		end,
		removeUser = function(userId: number)
			private.remove(tostring(userId))
		end,
		count = function(): number
			return public.count() + private.count()
		end,
		destroy = function()
			public.destroy()
			private.destroy()
		end,
	}
end
return table.freeze(Fixture)
