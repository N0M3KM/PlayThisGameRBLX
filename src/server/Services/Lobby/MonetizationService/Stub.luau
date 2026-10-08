--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Payloads = require(Shared.Contracts.Payloads)
local Result = require(Shared.Contracts.Result)
local ServiceStub = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceStub)
local Interface = require(script.Parent.Interface)

return function(): Interface.Interface
	local stub = ServiceStub.new("MonetizationService", { "ProcessReceipt", "QueryPass" })
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
		ProcessReceipt = function(
			_self: ServiceStub.Stub,
			_receipt: Payloads.ReceiptInput
		): Result.Result<Payloads.ReceiptDecision>
			return stub:Call("ProcessReceipt")
		end,
		QueryPass = function(
			_self: ServiceStub.Stub,
			_userId: number,
			_passId: number
		): Result.Result<boolean>
			return stub:Call("QueryPass")
		end,
	}
	return result
end
