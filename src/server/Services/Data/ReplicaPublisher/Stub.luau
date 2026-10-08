--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Payloads = require(Shared.Contracts.Payloads)
local Result = require(Shared.Contracts.Result)
local ServiceStub = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceStub)
local Interface = require(script.Parent.Interface)

return function(): Interface.Interface
	local stub =
		ServiceStub.new("ReplicaPublisher", { "PublishPrivate", "PublishMatch", "PublishBoard", "Remove" })
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
		PublishPrivate = function(
			_self: ServiceStub.Stub,
			_userId: number,
			_snapshot: Payloads.PlayerDataSnapshot
		): Result.Result<boolean>
			return stub:Call("PublishPrivate")
		end,
		PublishMatch = function(
			_self: ServiceStub.Stub,
			_snapshot: Payloads.MatchSnapshot
		): Result.Result<boolean>
			return stub:Call("PublishMatch")
		end,
		Remove = function(_self: ServiceStub.Stub, _userId: number): Result.Result<boolean>
			return stub:Call("Remove")
		end,
		PublishBoard = function(
			_self: ServiceStub.Stub,
			_snapshot: Payloads.BoardSnapshot
		): Result.Result<boolean>
			return stub:Call("PublishBoard")
		end,
	}
	return result
end
