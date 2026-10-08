--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Payloads = require(Shared.Contracts.Payloads)
local Result = require(Shared.Contracts.Result)
local ServiceStub = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceStub)
local Interface = require(script.Parent.Interface)

return function(): Interface.Interface
	local stub = ServiceStub.new("StatService", { "Add", "RemoveSource", "Resolve" })
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
		Add = function(
			_self: ServiceStub.Stub,
			_entity: Payloads.EntityRef,
			_modifier: Payloads.StatModifier
		): Result.Result<boolean>
			return stub:Call("Add")
		end,
		RemoveSource = function(
			_self: ServiceStub.Stub,
			_entity: Payloads.EntityRef,
			_sourceId: string
		): Result.Result<boolean>
			return stub:Call("RemoveSource")
		end,
		Resolve = function(
			_self: ServiceStub.Stub,
			_entity: Payloads.EntityRef
		): Result.Result<{ [string]: number }>
			return stub:Call("Resolve")
		end,
	}
	return result
end
