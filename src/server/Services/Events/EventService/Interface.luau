--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.EventService
return table.freeze({
	Name = "EventService",
	Draft = true,
	Commands = table.freeze({ "StartPlan", "StopAll", "Query" }),
})
