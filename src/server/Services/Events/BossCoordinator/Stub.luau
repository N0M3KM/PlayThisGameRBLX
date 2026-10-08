--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Payloads = require(Shared.Contracts.Payloads)
local Result = require(Shared.Contracts.Result)
local ServiceStub = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceStub)
local Interface = require(script.Parent.Interface)

return function(): Interface.Interface
	local stub =
		ServiceStub.new("BossCoordinator", { "SpawnRequired", "TrackDeath", "StopRound", "ObserveDeaths" })
	local result: Interface.Interface = {
		Name = stub.Name,
		ObserveDeaths = function(_self: ServiceStub.Stub, _callback: (number, string) -> ()): () -> ()
			return function() end
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
		SpawnRequired = function(
			_self: ServiceStub.Stub,
			_roundId: number,
			_instanceIds: { string }
		): Result.Result<{ Payloads.BossProgress }>
			return stub:Call("SpawnRequired")
		end,
		TrackDeath = function(_self: ServiceStub.Stub, _fact: Payloads.DamageFact): Result.Result<boolean>
			return stub:Call("TrackDeath")
		end,
		StopRound = function(_self: ServiceStub.Stub, _roundId: number): Result.Result<boolean>
			return stub:Call("StopRound")
		end,
	}
	return result
end
