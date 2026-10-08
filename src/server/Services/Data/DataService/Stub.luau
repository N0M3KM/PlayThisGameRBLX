--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Payloads = require(Shared.Contracts.Payloads)
local Result = require(Shared.Contracts.Result)
local ServiceStub = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceStub)
local Interface = require(script.Parent.Interface)

return function(): Interface.Interface
	local stub = ServiceStub.new("DataService", { "OpenSession", "Read", "Transact", "Save", "Release" })
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
		OpenSession = function(_self: ServiceStub.Stub, _userId: number): Result.Result<boolean>
			return stub:Call("OpenSession")
		end,
		Read = function(_self: ServiceStub.Stub, _userId: number): Result.Result<Payloads.PlayerDataSnapshot>
			return stub:Call("Read")
		end,
		Transact = function(
			_self: ServiceStub.Stub,
			_transaction: Payloads.EconomyTransaction
		): Result.Result<Payloads.TransactionReceipt>
			return stub:Call("Transact")
		end,
		Save = function(_self: ServiceStub.Stub, _userId: number): Result.Result<boolean>
			return stub:Call("Save")
		end,
		Release = function(_self: ServiceStub.Stub, _userId: number): Result.Result<boolean>
			return stub:Call("Release")
		end,
	}
	return result
end
