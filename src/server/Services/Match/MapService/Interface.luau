--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.MapService
return table.freeze({
	Name = "MapService",
	Draft = true,
	Commands = table.freeze({ "Load", "Validate", "GetSpawns", "GetContext", "Unload" }),
})
