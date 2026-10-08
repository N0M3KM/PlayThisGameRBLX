--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.LoadoutService
return table.freeze({
	Name = "LoadoutService",
	Draft = true,
	Commands = table.freeze({ "Equip", "SnapshotAndLock", "Grant", "Unlock", "Clear" }),
})
