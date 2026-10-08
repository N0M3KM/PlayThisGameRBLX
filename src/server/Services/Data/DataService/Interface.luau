--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.DataService
return table.freeze({
	Name = "DataService",
	Draft = true,
	Commands = table.freeze({ "OpenSession", "Read", "Transact", "Save", "Release" }),
})
