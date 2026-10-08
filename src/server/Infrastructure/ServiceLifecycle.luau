--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Service = require(Shared.Contracts.Service)
local Scope = require(Shared.Util.Scope)
local Lifecycle = {}
local NOT_READY: Service.StubResult = { Ok = false, Code = "NotReady" }
table.freeze(NOT_READY)
export type Hooks = { Start: (() -> ())?, Stop: (() -> ())? }

--[=[ Shared facade lifecycle; implementations resolve dependencies during Start, after registration. ]=]
function Lifecycle.new(name: string, scope: Scope.Scope, hooks: Hooks?): Service.Interface
	local initialized, started, destroyed = false, false, false
	local function stop()
		if not started then
			return
		end
		started = false
		if hooks and hooks.Stop then
			hooks.Stop()
		end
	end
	return {
		Name = name,
		IsStub = false,
		Init = function(_self: Service.Interface)
			assert(not destroyed, `Cannot initialize destroyed {name}`)
			initialized = true
		end,
		Start = function(_self: Service.Interface)
			assert(initialized and not started and not destroyed, `Invalid {name} start`)
			started = true
			if hooks and hooks.Start then
				local outcome = table.pack(pcall(hooks.Start))
				if not outcome[1] then
					started = false
					error(tostring(outcome[2]), 0)
				end
			end
		end,
		Stop = function(_self: Service.Interface)
			stop()
		end,
		Destroy = function(_self: Service.Interface)
			if destroyed then
				return
			end
			destroyed = true
			local outcome = table.pack(pcall(stop))
			local errors = scope:destroy()
			if not outcome[1] then
				warn(`{name} stop failed: {tostring(outcome[2])}`)
			end
			for _, message in errors do
				warn(`{name} cleanup failed: {message}`)
			end
		end,
		IsStarted = function(_self: Service.Interface): boolean
			return started and not destroyed
		end,
		Call = function(
			_self: Service.Interface,
			_command: string,
			_arguments: Service.Arguments?
		): Service.StubResult
			-- Legacy generic calls cannot bypass typed implementation methods.
			return NOT_READY
		end,
	}
end
return table.freeze(Lifecycle)
