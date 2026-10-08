--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.AdminDebugService
return table.freeze({
	Name = "AdminDebugService",
	Draft = true,
	Commands = table.freeze({ "ExecuteAllowlisted" }),
})
