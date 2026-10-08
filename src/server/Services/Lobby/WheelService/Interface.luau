--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local DomainInterfaces = require(Shared.Contracts.DomainInterfaces)
export type Interface = DomainInterfaces.WheelService
return table.freeze({
	Name = "WheelService",
	Draft = true,
	Commands = table.freeze({ "RequestFreeSpin", "SpendPaidSpin", "CheckpointOnlineCooldown" }),
})
