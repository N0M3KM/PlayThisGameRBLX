--!strict
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Domain = require("@game/ReplicatedStorage/Shared/Contracts/DomainInterfaces")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Service = require("@game/ReplicatedStorage/Shared/Contracts/Service")
local Ammo = require("@game/ReplicatedStorage/Shared/Util/Combat/AmmoModel")
local Loadout = require("../LoadoutService/Types")
export type Tuning = {
	Speed: number?,
	CooldownSeconds: number?,
	ReloadSeconds: number?,
	Range: number?,
	Width: number?,
	Height: number?,
	KnockbackSpeed: number?,
	JumpMultiplier: number?,
}
export type Dependencies = {
	loadout: Loadout.Api,
	stats: Domain.StatService,
	projectiles: Domain.ProjectileService,
	projectilesReady: () -> boolean,
	clock: () -> number,
	active: (number) -> boolean,
	entity: (number, number, number) -> Payloads.EntityRef?,
	melee: (Payloads.EntityRef, number, Tuning) -> Result.Result<boolean>,
	tuning: (string) -> Tuning?,
	ability: ((Payloads.EntityRef, string, string) -> Result.Result<boolean>)?,
}
export type Api = Domain.GearService & {
	BindTool: (Service.Interface, number, number, number, number, Tool) -> (),
	GetAmmo: (Service.Interface, number, number) -> Result.Result<Ammo.Snapshot>,
}
return table.freeze({})
