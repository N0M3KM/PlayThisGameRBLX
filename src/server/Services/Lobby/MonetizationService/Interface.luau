--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.MonetizationService
return table.freeze({
	Name = "MonetizationService",
	Draft = true,
	Commands = table.freeze({ "ProcessReceipt", "QueryPass" }),
})
