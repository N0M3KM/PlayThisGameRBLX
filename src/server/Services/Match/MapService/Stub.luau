--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Payloads = require(Shared.Contracts.Payloads)
local Result = require(Shared.Contracts.Result)
local ServiceStub = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceStub)
local Interface = require(script.Parent.Interface)

return function(): Interface.Interface
	local stub = ServiceStub.new("MapService", { "Load", "Validate", "GetSpawns", "GetContext", "Unload" })
	local result: Interface.Interface = {
		Name = stub.Name,
		IsStub = true,
		Init = function(_self: ServiceStub.Stub)
			stub:Init()
		end,
		Start = function(_self: ServiceStub.Stub)
			stub:Start()
		end,
		Stop = function(_self: ServiceStub.Stub)
			stub:Stop()
		end,
		Destroy = function(_self: ServiceStub.Stub)
			stub:Destroy()
		end,
		IsStarted = function(_self: ServiceStub.Stub): boolean
			return stub:IsStarted()
		end,
		Call = function(
			_self: ServiceStub.Stub,
			command: string,
			arguments: ServiceStub.Arguments?
		): ServiceStub.StubResult
			return stub:Call(command, arguments)
		end,
		Load = function(
			_self: ServiceStub.Stub,
			_roundId: number,
			_mapId: string
		): Result.Result<Payloads.MapContext>
			return stub:Call("Load")
		end,
		Validate = function(
			_self: ServiceStub.Stub,
			_map: Payloads.MapDescriptor
		): Result.Result<Payloads.MapDescriptor>
			return stub:Call("Validate")
		end,
		GetSpawns = function(_self: ServiceStub.Stub, _roundId: number): Result.Result<{ Payloads.Point }>
			return stub:Call("GetSpawns")
		end,
		Unload = function(_self: ServiceStub.Stub, _roundId: number): Result.Result<boolean>
			return stub:Call("Unload")
		end,
		GetContext = function(_self: ServiceStub.Stub, _roundId: number): Result.Result<Payloads.MapContext>
			return stub:Call("GetContext")
		end,
	}
	return result
end
