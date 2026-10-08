--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Payloads = require(Shared.Contracts.Payloads)
local Result = require(Shared.Contracts.Result)
local ServiceStub = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceStub)
local Interface = require(script.Parent.Interface)

return function(): Interface.Interface
	local stub = ServiceStub.new(
		"DamageService",
		{ "BeginRound", "Apply", "GetLedger", "GetContributions", "GetRoundStats", "ClearRound" }
	)
	local result: Interface.Interface = {
		Name = stub.Name,
		BeginRound = function(_self: ServiceStub.Stub, _roundId: number): Result.Result<boolean>
			return stub:Call("BeginRound")
		end,
		ClearRound = function(_self: ServiceStub.Stub, _roundId: number): Result.Result<boolean>
			return stub:Call("ClearRound")
		end,
		GetContributions = function(
			_self: ServiceStub.Stub,
			_entity: Payloads.EntityRef
		): Result.Result<{ [number]: number }>
			return stub:Call("GetContributions")
		end,
		GetRoundStats = function(
			_self: ServiceStub.Stub,
			_roundId: number
		): Result.Result<{ Payloads.RoundStat }>
			return stub:Call("GetRoundStats")
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
			_request: Payloads.DamageRequest
		): Result.Result<Payloads.DamageFact>
			return stub:Call("Apply")
		end,
		GetLedger = function(
			_self: ServiceStub.Stub,
			_entity: Payloads.EntityRef
		): Result.Result<{ Payloads.DamageFact }>
			return stub:Call("GetLedger")
		end,
	}
	return result
end
