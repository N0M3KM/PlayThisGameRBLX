--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.GameLoopService
return table.freeze({
	Name = "GameLoopService",
	Draft = true,
	Commands = table.freeze({ "GetState", "Advance", "Abort" }),
})
