--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.DroidService
return table.freeze({
	Name = "DroidService",
	Draft = true,
	Commands = table.freeze({ "StartSpawning", "Spawn", "Despawn", "Summon", "Query" }),
})
