--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.DestructionService
return table.freeze({ Name = "DestructionService", Draft = true, Commands = table.freeze({ "Explode" }) })
