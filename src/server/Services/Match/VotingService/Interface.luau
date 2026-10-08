--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.VotingService
return table.freeze({
	Name = "VotingService",
	Draft = true,
	Commands = table.freeze({ "Open", "Cast", "RemovePlayer", "Resolve" }),
})
