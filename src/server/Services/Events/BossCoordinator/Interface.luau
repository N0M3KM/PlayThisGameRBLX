--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.BossCoordinator
return table.freeze({
	Name = "BossCoordinator",
	Draft = true,
	Commands = table.freeze({ "SpawnRequired", "TrackDeath", "StopRound" }),
})
