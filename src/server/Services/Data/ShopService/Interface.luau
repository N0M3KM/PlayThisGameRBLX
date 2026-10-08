--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.ShopService
return table.freeze({ Name = "ShopService", Draft = true, Commands = table.freeze({ "Purchase" }) })
