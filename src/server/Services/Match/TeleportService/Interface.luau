--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.TeleportService
return table.freeze({
	Name = "TeleportService",
	Draft = true,
	Commands = table.freeze({ "ToMap", "ToLobby", "Cancel" }),
})
