--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.PlayerStateService
return table.freeze({
	Name = "PlayerStateService",
	Draft = true,
	Commands = table.freeze({
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
	}),
})
