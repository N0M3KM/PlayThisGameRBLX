--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.StatusEffectService
return table.freeze({
	Name = "StatusEffectService",
	Draft = true,
	Commands = table.freeze({ "Apply", "Remove", "Clear", "ClearRound" }),
})
