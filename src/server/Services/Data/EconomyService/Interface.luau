--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.EconomyService
return table.freeze({
	Name = "EconomyService",
	Draft = true,
	Commands = table.freeze({
		"SettleNonBossKill",
		"SettleBossContributors",
		"SettleSurvival",
		"AwardXP",
		"QueryBalance",
	}),
})
