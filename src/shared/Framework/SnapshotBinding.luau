--!strict
-- Transport-independent client binding. The eventual ReplicaService wrapper supplies subscription.
local Result = require("../Contracts/Result")
local Scope = require("../Util/Scope")
export type Options<T> = {
	Validate: (unknown) -> Result.Result<T>,
	RevisionOf: (T) -> number,
	RoundOf: ((T) -> number)?,
	OnChanged: (T) -> (),
	OnError: ((string) -> ())?,
}
export type Subscribe = ((unknown) -> ()) -> Scope.Cleanup
export type Binding<T> = {
	accept: (unknown) -> Result.Result<boolean>,
	read: () -> Result.Result<T>,
	bind: (Subscribe, Scope.Scope) -> (),
	destroy: () -> (),
}
local SnapshotBinding = {}

--[=[ Validates before applying. Revisions never move backwards across a binding's lifetime. ]=]
function SnapshotBinding.new<T>(options: Options<T>): Binding<T>
	local current: T? = nil
	local lastRevision, lastRound = -1, -1
	local destroyed, bound = false, false
	local release: Scope.Cleanup? = nil
	local function reportError(message: string)
		if options.OnError then
			pcall(options.OnError, string.sub(message, 1, 1000))
		end
	end
	local function destroy()
		if destroyed then
			return
		end
		destroyed = true
		current = nil
		if release then
			local disconnect = release
			release = nil
			disconnect()
		end
	end
	local function accept(value: unknown): Result.Result<boolean>
		if destroyed then
			return Result.failure("Unavailable")
		end
		local validated = options.Validate(value)
		if not validated.Ok then
			return Result.failure(validated.Code)
		end
		local snapshot = validated.Value
		local revision = options.RevisionOf(snapshot)
		local round = if options.RoundOf then options.RoundOf(snapshot) else lastRound
		-- Injected functions can yield or reenter teardown. They must never revive a closed binding.
		if destroyed then
			return Result.failure("Unavailable")
		end
		if revision <= lastRevision or round < lastRound then
			return Result.failure("StaleRound")
		end
		current, lastRevision, lastRound = snapshot, revision, round
		-- Listener failures cannot turn an applied snapshot into a retryable transport failure.
		local notified = table.pack(pcall(options.OnChanged, snapshot))
		if not notified[1] then
			reportError(tostring(notified[2]))
		end
		return Result.success(true)
	end
	return {
		accept = accept,
		read = function(): Result.Result<T>
			if destroyed then
				return Result.failure("Unavailable")
			end
			if current == nil then
				return Result.failure("NotReady")
			end
			return Result.success(current :: T)
		end,
		bind = function(subscribe: Subscribe, scope: Scope.Scope)
			assert(
				not destroyed and not bound and not scope:isDestroyed(),
				"Binding is closed or already bound"
			)
			bound = true
			local cleanupScope = scope:child()
			release = function()
				local errors = cleanupScope:destroy()
				for _, message in errors do
					reportError(message)
				end
			end
			cleanupScope:add(destroy)
			local outcome = table.pack(pcall(subscribe, function(value: unknown)
				accept(value)
			end))
			if not outcome[1] or type(outcome[2]) ~= "function" then
				destroy()
				error(
					if not outcome[1]
						then tostring(outcome[2])
						else "Subscription must return a disconnect function",
					0
				)
			end
			local disconnect = outcome[2] :: Scope.Cleanup
			if cleanupScope:isDestroyed() then
				disconnect()
			else
				cleanupScope:add(disconnect)
			end
		end,
		destroy = destroy,
	}
end

return table.freeze(SnapshotBinding)
