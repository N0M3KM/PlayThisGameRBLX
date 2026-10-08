--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.ReplicaPublisher
return table.freeze({
	Name = "ReplicaPublisher",
	Draft = true,
	Commands = table.freeze({ "PublishPrivate", "PublishMatch", "PublishBoard", "Remove" }),
})
