--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Payloads = require(Shared.Contracts.Payloads)
local Result = require(Shared.Contracts.Result)
local ServiceStub = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceStub)
local Interface = require(script.Parent.Interface)

return function(): Interface.Interface
	local stub = ServiceStub.new(
		"EconomyService",
		{ "SettleNonBossKill", "SettleBossContributors", "SettleSurvival", "AwardXP", "QueryBalance" }
	)
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
		SettleNonBossKill = function(
			_self: ServiceStub.Stub,
			_fact: Payloads.DamageFact
		): Result.Result<{ Payloads.TransactionReceipt }>
			return stub:Call("SettleNonBossKill")
		end,
		SettleBossContributors = function(
			_self: ServiceStub.Stub,
			_settlement: Payloads.BossSettlement
		): Result.Result<{ Payloads.TransactionReceipt }>
			return stub:Call("SettleBossContributors")
		end,
		SettleSurvival = function(
			_self: ServiceStub.Stub,
			_outcome: Payloads.RoundOutcome
		): Result.Result<{ Payloads.TransactionReceipt }>
			return stub:Call("SettleSurvival")
		end,
		AwardXP = function(
			_self: ServiceStub.Stub,
			_transaction: Payloads.EconomyTransaction
		): Result.Result<Payloads.TransactionReceipt>
			return stub:Call("AwardXP")
		end,
		QueryBalance = function(_self: ServiceStub.Stub, _userId: number): Result.Result<number>
			return stub:Call("QueryBalance")
		end,
	}
	return result
end
