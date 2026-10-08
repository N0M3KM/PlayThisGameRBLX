--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Payloads = require(Shared.Contracts.Payloads)
local Result = require(Shared.Contracts.Result)
local ServiceStub = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceStub)
local Interface = require(script.Parent.Interface)

return function(): Interface.Interface
	local stub = ServiceStub.new("DialogueService", { "Open", "Choose", "Close" })
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
		Open = function(
			_self: ServiceStub.Stub,
			_userId: number,
			_npcId: string
		): Result.Result<Payloads.DialogueSession>
			return stub:Call("Open")
		end,
		Choose = function(
			_self: ServiceStub.Stub,
			_userId: number,
			_sessionId: string,
			_choiceId: string
		): Result.Result<Payloads.DialogueSession>
			return stub:Call("Choose")
		end,
		Close = function(
			_self: ServiceStub.Stub,
			_userId: number,
			_sessionId: string
		): Result.Result<boolean>
			return stub:Call("Close")
		end,
	}
	return result
end
