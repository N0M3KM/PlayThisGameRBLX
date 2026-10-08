--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Payloads = require(Shared.Contracts.Payloads)
local Result = require(Shared.Contracts.Result)
local ServiceStub = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceStub)
local Interface = require(script.Parent.Interface)

return function(): Interface.Interface
	local stub = ServiceStub.new("UtilityService", { "Use", "GetRemainingUses", "Clear" })
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
		Use = function(
			_self: ServiceStub.Stub,
			_userId: number,
			_intent: Payloads.UtilityIntent
		): Result.Result<boolean>
			return stub:Call("Use")
		end,
		GetRemainingUses = function(
			_self: ServiceStub.Stub,
			_userId: number,
			_utilityId: string
		): Result.Result<number>
			return stub:Call("GetRemainingUses")
		end,
		Clear = function(_self: ServiceStub.Stub, _userId: number): Result.Result<boolean>
			return stub:Call("Clear")
		end,
	}
	return result
end
