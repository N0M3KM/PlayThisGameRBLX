--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.DialogueService
return table.freeze({
	Name = "DialogueService",
	Draft = true,
	Commands = table.freeze({ "Open", "Choose", "Close" }),
})
