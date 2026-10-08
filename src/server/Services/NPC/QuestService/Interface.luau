--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.QuestService
return table.freeze({
	Name = "QuestService",
	Draft = true,
	Commands = table.freeze({ "Accept", "Progress", "Complete" }),
})
