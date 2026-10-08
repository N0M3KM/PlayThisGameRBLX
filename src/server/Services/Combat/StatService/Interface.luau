--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.StatService
return table.freeze({
	Name = "StatService",
	Draft = true,
	Commands = table.freeze({ "Add", "RemoveSource", "Resolve" }),
})
