--!strict
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Domain = require("@game/ReplicatedStorage/Shared/Contracts/DomainInterfaces")
local States = require("@game/ReplicatedStorage/Shared/Contracts/States")

export type Entity = {
	Ref: Payloads.EntityRef,
	Faction: States.Faction,
	Hp: number,
	MaxHp: number,
	IsBoss: boolean,
	BulletImmune: boolean,
	OwnerUserId: number?,
}
-- Adapter methods must not yield. writeHp performs an atomic expected-HP comparison;
-- failure means no mutation; success returns the committed HP in [0, expectedHp].
export type Adapter = {
	resolve: (Payloads.EntityRef) -> Result.Result<Entity>,
	roundActive: (number) -> boolean,
	modifiers: (Entity, Entity, Payloads.DamageRequest) -> Result.Result<{ Dealt: number, Taken: number }>,
	writeHp: (Entity, number, number) -> Result.Result<number>,
}
export type Limits = {
	MaxEntitiesPerRound: number,
	MaxFactsPerEntity: number,
	MaxContributorsPerEntity: number,
	MaxRoundPlayers: number,
}
export type Damage = Domain.DamageService
return table.freeze({})
