--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.GearService
return table.freeze({
	Name = "GearService",
	Draft = true,
	Commands = table.freeze({ "Use", "Reload", "Ability", "Clear" }),
})
