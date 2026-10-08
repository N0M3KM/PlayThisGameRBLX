--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Payloads = require(Shared.Contracts.Payloads)
local Result = require(Shared.Contracts.Result)
local ServiceStub = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceStub)
local Interface = require(script.Parent.Interface)

return function(): Interface.Interface
	local stub =
		ServiceStub.new("DroidBrainHost", { "PublishSnapshot", "Schedule", "CollectDecisions", "StopRound" })
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
		PublishSnapshot = function(
			_self: ServiceStub.Stub,
			_roundId: number,
			_snapshots: { Payloads.TargetSnapshot }
		): Result.Result<boolean>
			return stub:Call("PublishSnapshot")
		end,
		Schedule = function(
			_self: ServiceStub.Stub,
			_roundId: number,
			_budget: number
		): Result.Result<boolean>
			return stub:Call("Schedule")
		end,
		CollectDecisions = function(
			_self: ServiceStub.Stub,
			_roundId: number
		): Result.Result<{ Payloads.BrainDecision }>
			return stub:Call("CollectDecisions")
		end,
		StopRound = function(_self: ServiceStub.Stub, _roundId: number): Result.Result<boolean>
			return stub:Call("StopRound")
		end,
	}
	return result
end
