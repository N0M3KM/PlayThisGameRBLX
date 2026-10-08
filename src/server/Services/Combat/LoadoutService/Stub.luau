--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Payloads = require(Shared.Contracts.Payloads)
local Requests = require(Shared.Contracts.Requests)
local Result = require(Shared.Contracts.Result)
local ServiceStub = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceStub)
local Interface = require(script.Parent.Interface)

return function(): Interface.Interface
	local stub = ServiceStub.new("LoadoutService", {
		"Equip",
		"EquipSelection",
		"SnapshotAndLock",
		"GetLocked",
		"Grant",
		"Unlock",
		"Clear",
		"ClearRound",
	})
	local result: Interface.Interface = {
		Name = stub.Name,
		ClearRound = function(_self: ServiceStub.Stub, _roundId: number)
			stub:Call("ClearRound")
		end,
		EquipSelection = function(
			_self: ServiceStub.Stub,
			_userId: number,
			_request: Requests.EquipLoadout
		): Result.Result<boolean>
			return stub:Call("EquipSelection")
		end,
		GetLocked = function(
			_self: ServiceStub.Stub,
			_userId: number,
			_roundId: number
		): Result.Result<Payloads.LoadoutSnapshot>
			return stub:Call("GetLocked")
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
		Equip = function(
			_self: ServiceStub.Stub,
			_userId: number,
			_slot: number,
			_contentId: string
		): Result.Result<boolean>
			return stub:Call("Equip")
		end,
		SnapshotAndLock = function(
			_self: ServiceStub.Stub,
			_userId: number,
			_roundId: number
		): Result.Result<Payloads.LoadoutSnapshot>
			return stub:Call("SnapshotAndLock")
		end,
		Grant = function(_self: ServiceStub.Stub, _userId: number, _roundId: number): Result.Result<boolean>
			return stub:Call("Grant")
		end,
		Unlock = function(_self: ServiceStub.Stub, _userId: number, _roundId: number): Result.Result<boolean>
			return stub:Call("Unlock")
		end,
		Clear = function(_self: ServiceStub.Stub, _userId: number): Result.Result<boolean>
			return stub:Call("Clear")
		end,
	}
	return result
end
