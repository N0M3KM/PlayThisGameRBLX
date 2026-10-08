--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.PickQueue
return table.freeze({
	Name = "PickQueue",
	Draft = true,
	Commands = table.freeze({ "SubmitSelection", "TakeNextEligible", "Restore" }),
})
