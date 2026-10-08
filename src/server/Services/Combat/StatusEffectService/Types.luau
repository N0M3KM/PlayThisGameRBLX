--!strict
local Domain = require("@game/ReplicatedStorage/Shared/Contracts/DomainInterfaces")
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
export type Controls = { Stunned: boolean, Ragdolled: boolean }
export type Definition = { Modifiers: { Payloads.StatModifier }, Stun: boolean?, Ragdoll: boolean? }
export type Dependencies = {
	stats: Domain.StatService,
	current: (Payloads.EntityRef) -> boolean,
	clock: () -> number,
	after: (number, () -> ()) -> () -> (),
	definitions: { [string]: Definition },
	movement: ((Payloads.EntityRef, Controls) -> ())?,
}
export type Api = Domain.StatusEffectService
return table.freeze({})
