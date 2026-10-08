--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Payloads = require(Shared.Contracts.Payloads)
local Result = require(Shared.Contracts.Result)
local ServiceStub = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceStub)
local Interface = require(script.Parent.Interface)

return function(): Interface.Interface
	local stub = ServiceStub.new("GameLoopService", { "GetState", "Advance", "Abort", "ReportBossDeath" })
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
		GetState = function(_self: ServiceStub.Stub): Result.Result<Payloads.MatchSnapshot>
			return stub:Call("GetState")
		end,
		Advance = function(_self: ServiceStub.Stub, _expectedRoundId: number): Result.Result<boolean>
			return stub:Call("Advance")
		end,
		Abort = function(
			_self: ServiceStub.Stub,
			_expectedRoundId: number,
			_reason: string
		): Result.Result<boolean>
			return stub:Call("Abort")
		end,
		ReportBossDeath = function(
			_self: ServiceStub.Stub,
			_roundId: number,
			_instanceId: string
		): Result.Result<boolean>
			return stub:Call("ReportBossDeath")
		end,
	}
	return result
end
