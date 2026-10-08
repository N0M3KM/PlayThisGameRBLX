--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.ScenarioDirector
return table.freeze({
	Name = "ScenarioDirector",
	Draft = true,
	Commands = table.freeze({ "SelectScenario", "SelectEvents", "SelectBosses" }),
})
