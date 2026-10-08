--!strict
-- Server-only ports; these values are never sent to workers or clients.
local Domain = require("./DomainInterfaces")
local Payloads = require("./Payloads")
local Result = require("./Result")
export type Shot = {
	Source: Payloads.EntityRef,
	Target: Payloads.EntityRef,
	Origin: Payloads.Point,
	Direction: Payloads.Point,
	Damage: number,
	Speed: number,
	Range: number,
	ShotId: string,
	Kind: "Bullet" | "Paper",
}
export type Port<M> = {
	register: (Payloads.EntityRef, M, "Hostile" | "Allied", boolean, number?) -> Result.Result<boolean>,
	unregister: (Payloads.EntityRef) -> (),
	model: (Payloads.EntityRef) -> M?,
	stats: Domain.StatService,
	controlLocked: (Payloads.EntityRef) -> boolean,
	refresh: (Payloads.EntityRef) -> (),
	damage: Domain.DamageService,
	status: Domain.StatusEffectService,
	projectile: ((Shot) -> Result.Result<boolean>)?,
}
export type Tuning = {
	ShootDamage: number?,
	ShootCooldownSeconds: number?,
	ProjectileSpeed: number?,
	WindMeleeCooldownSeconds: number?,
	ShockRange: number?,
	LungeStunSeconds: number?,
	LungeRagdollSeconds: number?,
	LungeSpeed: number?,
}
return table.freeze({ Version = 0, Frozen = false })
