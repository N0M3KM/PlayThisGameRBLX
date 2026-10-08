--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Result = require(Shared.Contracts.Result)
local ServiceStub = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceStub)
local Interface = require(script.Parent.Interface)

return function(): Interface.Interface
	local stub = ServiceStub.new("TeleportService", { "ToMap", "ToLobby", "Cancel" })
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
		ToMap = function(
			_self: ServiceStub.Stub,
			_roundId: number,
			_mapId: string,
			_participants: { number }
		): Result.Result<{ number }>
			return stub:Call("ToMap")
		end,
		ToLobby = function(
			_self: ServiceStub.Stub,
			_userId: number,
			_generation: number
		): Result.Result<boolean>
			return stub:Call("ToLobby")
		end,
		Cancel = function(_self: ServiceStub.Stub, _roundId: number): Result.Result<boolean>
			return stub:Call("Cancel")
		end,
	}
	return result
end
