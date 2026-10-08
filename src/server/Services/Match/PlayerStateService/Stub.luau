--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Payloads = require(Shared.Contracts.Payloads)
local Result = require(Shared.Contracts.Result)
local ServiceStub = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceStub)
local Interface = require(script.Parent.Interface)
local States = require(Shared.Contracts.States)

return function(): Interface.Interface
	local stub = ServiceStub.new("PlayerStateService", {
		"Get",
		"Transition",
		"SetAfk",
		"GetAlive",
		"EligiblePlayers",
		"IsAfk",
		"BeginRound",
		"ResetRound",
		"ReserveLobby",
		"ValidateLobbyReservation",
		"ReleaseLobby",
	})
	local result: Interface.Interface = {
		Name = stub.Name,
		IsStub = true,
		ReserveLobby = function(
			_self: ServiceStub.Stub,
			_userId: number
		): Result.Result<Payloads.LobbyReservation>
			return stub:Call("ReserveLobby")
		end,
		ValidateLobbyReservation = function(
			_self: ServiceStub.Stub,
			_reservation: Payloads.LobbyReservation
		): boolean
			return false
		end,
		ReleaseLobby = function(
			_self: ServiceStub.Stub,
			_reservation: Payloads.LobbyReservation
		): Result.Result<boolean>
			return stub:Call("ReleaseLobby")
		end,
		EligiblePlayers = function(_self: ServiceStub.Stub): { number }
			return table.freeze({})
		end,
		IsAfk = function(_self: ServiceStub.Stub, _userId: number): boolean
			return true
		end,
		BeginRound = function(_self: ServiceStub.Stub, _roundId: number, _userIds: { number }): { number }
			return table.freeze({})
		end,
		ResetRound = function(_self: ServiceStub.Stub, _roundId: number) end,
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
		Get = function(_self: ServiceStub.Stub, _userId: number): Result.Result<Payloads.PlayerStateSnapshot>
			return stub:Call("Get")
		end,
		Transition = function(
			_self: ServiceStub.Stub,
			_userId: number,
			_expectedState: States.PlayerState,
			_nextState: States.PlayerState,
			_expectedRoundId: number,
			_generation: number
		): Result.Result<boolean>
			return stub:Call("Transition")
		end,
		SetAfk = function(_self: ServiceStub.Stub, _userId: number, _afk: boolean): Result.Result<boolean>
			return stub:Call("SetAfk")
		end,
		GetAlive = function(_self: ServiceStub.Stub, _roundId: number): Result.Result<{ number }>
			return stub:Call("GetAlive")
		end,
	}
	return result
end
