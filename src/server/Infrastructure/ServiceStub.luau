--!strict
export type Arguments = { [string]: unknown }
export type StubResult = { Ok: false, Code: "NotReady" }
export type Stub = {
	Name: string,
	IsStub: boolean,
	Init: (self: Stub) -> (),
	Start: (self: Stub) -> (),
	Stop: (self: Stub) -> (),
	Destroy: (self: Stub) -> (),
	Call: (self: Stub, command: string, arguments: Arguments?) -> StubResult,
	IsStarted: (self: Stub) -> boolean,
}
local ServiceStub = {}

--[=[ Safe Interface substitute: never grants, writes profiles or acknowledges receipts. ]=]
function ServiceStub.new(name: string, commands: { string }): Stub
	local available: { [string]: boolean } = {}
	for _, command in commands do
		assert(not available[command], "Duplicate stub command")
		available[command] = true
	end
	local initialized, started, destroyed = false, false, false
	return {
		Name = name,
		IsStub = true,
		Init = function(_self: Stub)
			assert(not destroyed, "Cannot initialize destroyed stub")
			initialized = true
		end,
		Start = function(_self: Stub)
			assert(initialized and not destroyed and not started, "Invalid stub start")
			started = true
		end,
		Stop = function(_self: Stub)
			started = false
		end,
		Destroy = function(_self: Stub)
			started = false
			destroyed = true
		end,
		IsStarted = function(_self: Stub): boolean
			return started
		end,
		Call = function(_self: Stub, command: string, _arguments: Arguments?): StubResult
			assert(available[command], `Unknown {name} stub command: {command}`)
			local result: StubResult = { Ok = false, Code = "NotReady" }
			return table.freeze(result)
		end,
	}
end

return table.freeze(ServiceStub)
