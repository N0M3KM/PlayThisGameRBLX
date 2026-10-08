--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.LeaderboardService
return table.freeze({
	Name = "LeaderboardService",
	Draft = true,
	Commands = table.freeze({ "Submit", "GetTop50" }),
})
