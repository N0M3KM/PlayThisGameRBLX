--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Payloads = require(Shared.Contracts.Payloads)
local Result = require(Shared.Contracts.Result)
local ServiceStub = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceStub)
local Interface = require(script.Parent.Interface)

return function(): Interface.Interface
	local stub = ServiceStub.new("ScenarioDirector", { "SelectScenario", "SelectEvents", "SelectBosses" })
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
		SelectScenario = function(
			_self: ServiceStub.Stub,
			_roundId: number,
			_preferredScenarioId: string?
		): Result.Result<string>
			return stub:Call("SelectScenario")
		end,
		SelectEvents = function(
			_self: ServiceStub.Stub,
			_roundId: number,
			_scenarioId: string
		): Result.Result<Payloads.EventPlan>
			return stub:Call("SelectEvents")
		end,
		SelectBosses = function(
			_self: ServiceStub.Stub,
			_roundId: number,
			_scenarioId: string
		): Result.Result<{ string }>
			return stub:Call("SelectBosses")
		end,
	}
	return result
end
