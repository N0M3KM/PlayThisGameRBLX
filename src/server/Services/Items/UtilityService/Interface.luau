--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.UtilityService
return table.freeze({
	Name = "UtilityService",
	Draft = true,
	Commands = table.freeze({ "Use", "GetRemainingUses", "Clear" }),
})
