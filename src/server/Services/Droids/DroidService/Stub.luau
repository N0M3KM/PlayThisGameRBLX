--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Payloads = require(Shared.Contracts.Payloads)
local Result = require(Shared.Contracts.Result)
local ServiceStub = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceStub)
local Interface = require(script.Parent.Interface)

return function(): Interface.Interface
	local stub = ServiceStub.new(
		"DroidService",
		{ "StartSpawning", "Spawn", "Despawn", "Summon", "Query", "StopRound" }
	)
	local result: Interface.Interface = {
		Name = stub.Name,
		StopRound = function(_self: ServiceStub.Stub, _roundId: number): Result.Result<boolean>
			return stub:Call("StopRound")
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
		StartSpawning = function(
			_self: ServiceStub.Stub,
			_roundId: number,
			_mapId: string
		): Result.Result<boolean>
			return stub:Call("StartSpawning")
		end,
		Spawn = function(
			_self: ServiceStub.Stub,
			_request: Payloads.SpawnRequest
		): Result.Result<Payloads.EntityRef>
			return stub:Call("Spawn")
		end,
		Despawn = function(
			_self: ServiceStub.Stub,
			_entity: Payloads.EntityRef,
			_reason: string
		): Result.Result<boolean>
			return stub:Call("Despawn")
		end,
		Summon = function(
			_self: ServiceStub.Stub,
			_request: Payloads.SpawnRequest,
			_ownerUserId: number
		): Result.Result<Payloads.EntityRef>
			return stub:Call("Summon")
		end,
		Query = function(
			_self: ServiceStub.Stub,
			_entity: Payloads.EntityRef
		): Result.Result<Payloads.TargetSnapshot>
			return stub:Call("Query")
		end,
	}
	return result
end
