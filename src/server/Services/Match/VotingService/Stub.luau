--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Result = require(Shared.Contracts.Result)
local ServiceStub = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceStub)
local Interface = require(script.Parent.Interface)

return function(): Interface.Interface
	local stub = ServiceStub.new("VotingService", { "Open", "Cast", "RemovePlayer", "Resolve", "Close" })
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
		Open = function(
			_self: ServiceStub.Stub,
			_roundId: number,
			_choices: { string },
			_deadline: number
		): Result.Result<boolean>
			return stub:Call("Open")
		end,
		Cast = function(
			_self: ServiceStub.Stub,
			_userId: number,
			_roundId: number,
			_mapId: string
		): Result.Result<boolean>
			return stub:Call("Cast")
		end,
		RemovePlayer = function(_self: ServiceStub.Stub, _userId: number): Result.Result<boolean>
			return stub:Call("RemovePlayer")
		end,
		Resolve = function(_self: ServiceStub.Stub, _roundId: number): Result.Result<string>
			return stub:Call("Resolve")
		end,
		Close = function(_self: ServiceStub.Stub) end,
	}
	return result
end
