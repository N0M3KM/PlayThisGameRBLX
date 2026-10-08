--!strict
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local States = require("@game/ReplicatedStorage/Shared/Contracts/States")

export type Weapon = {
	Damage: number,
	Speed: number,
	Range: number,
	Muzzle: Payloads.Point,
	Faction: States.Faction,
	RaycastParams: unknown?,
}
export type Adapter = {
	weapon: (Payloads.EntityRef, string) -> Result.Result<Weapon>,
	current: (Payloads.EntityRef, string) -> boolean,
	roundActive: (number) -> boolean,
	hitEntity: (unknown) -> Payloads.EntityRef?,
	applyDamage: (Payloads.DamageRequest) -> Result.Result<Payloads.DamageFact>,
}
export type Limits = {
	MaxActiveCasts: number,
	MaxShotsPerRound: number,
	MaxOriginDistance: number,
	UnitTolerance: number,
}
export type Launch = {
	Origin: Payloads.Point,
	Direction: Payloads.Point,
	Speed: number,
	Range: number,
	RaycastParams: unknown?,
}
export type Handle = { cancel: () -> Result.Result<boolean> }
-- Transport is the mandated FastCast adapter or an explicit test fixture, never a fallback simulator.
export type Transport = {
	fire: (Launch, (unknown) -> (), () -> ()) -> Result.Result<Handle>,
	clear: () -> Result.Result<boolean>,
	destroy: () -> Result.Result<boolean>,
}
return table.freeze({})
