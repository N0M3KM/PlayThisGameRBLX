--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Requests = require(Shared.Contracts.Requests)
local Result = require(Shared.Contracts.Result)
local ServiceStub = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceStub)
local Interface = require(script.Parent.Interface)

return function(): Interface.Interface
	local stub = ServiceStub.new("GearService", { "Use", "Reload", "Ability", "Clear" })
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
		Use = function(
			_self: ServiceStub.Stub,
			_userId: number,
			_intent: Requests.UseGear
		): Result.Result<boolean>
			return stub:Call("Use")
		end,
		Reload = function(
			_self: ServiceStub.Stub,
			_userId: number,
			_intent: Requests.ReloadGear
		): Result.Result<boolean>
			return stub:Call("Reload")
		end,
		Ability = function(
			_self: ServiceStub.Stub,
			_userId: number,
			_intent: Requests.UseAbility
		): Result.Result<boolean>
			return stub:Call("Ability")
		end,
		Clear = function(_self: ServiceStub.Stub, _userId: number): Result.Result<boolean>
			return stub:Call("Clear")
		end,
	}
	return result
end
