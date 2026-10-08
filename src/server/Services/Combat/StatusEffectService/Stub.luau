--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Payloads = require(Shared.Contracts.Payloads)
local Result = require(Shared.Contracts.Result)
local ServiceStub = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceStub)
local Interface = require(script.Parent.Interface)

return function(): Interface.Interface
	local stub = ServiceStub.new("StatusEffectService", { "Apply", "Remove", "Clear", "ClearRound" })
	local result: Interface.Interface = {
		Name = stub.Name,
		ClearRound = function(_self: ServiceStub.Stub, _roundId: number)
			stub:Call("ClearRound")
		end,
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
		Apply = function(
			_self: ServiceStub.Stub,
			_entity: Payloads.EntityRef,
			_statusId: string,
			_sourceId: string,
			_duration: number
		): Result.Result<boolean>
			return stub:Call("Apply")
		end,
		Remove = function(
			_self: ServiceStub.Stub,
			_entity: Payloads.EntityRef,
			_sourceId: string
		): Result.Result<boolean>
			return stub:Call("Remove")
		end,
		Clear = function(_self: ServiceStub.Stub, _entity: Payloads.EntityRef): Result.Result<boolean>
			return stub:Call("Clear")
		end,
	}
	return result
end
