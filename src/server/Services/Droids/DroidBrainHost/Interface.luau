--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.DroidBrainHost
return table.freeze({
	Name = "DroidBrainHost",
	Draft = true,
	Commands = table.freeze({ "PublishSnapshot", "Schedule", "CollectDecisions", "StopRound" }),
})
