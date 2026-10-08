--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.ProjectileService
return table.freeze({
	Name = "ProjectileService",
	Draft = true,
	Commands = table.freeze({ "Cast", "CancelRound" }),
})
