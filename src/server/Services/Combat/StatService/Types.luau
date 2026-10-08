--!strict
local Domain = require("@game/ReplicatedStorage/Shared/Contracts/DomainInterfaces")
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Calculator = require("@game/ReplicatedStorage/Shared/Util/Combat/StatModifier")
export type Dependencies = {
	base: (Payloads.EntityRef) -> Result.Result<Calculator.Stats>,
	current: (Payloads.EntityRef) -> boolean,
	Policy: Calculator.Policy,
	changed: ((Payloads.EntityRef) -> ())?,
}
export type Api = Domain.StatService
return table.freeze({})
