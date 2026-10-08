--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.DamageService
return table.freeze({
	Name = "DamageService",
	Draft = true,
	Commands = table.freeze({ "Apply", "GetLedger" }),
})
