--!strict
local Domain = require("@game/ReplicatedStorage/Shared/Contracts/DomainInterfaces")
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local DroidAI = require("@game/ReplicatedStorage/Shared/Contracts/DroidAI")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local Definitions = require("@game/ReplicatedStorage/Shared/Config/Droids/Types")
export type Setup = {
	Context: Payloads.MapContext,
	MapRate: number,
	ScenarioMultiplier: number,
	EventMultiplier: number,
}
export type Record = {
	Entity: Payloads.EntityRef,
	Definition: Definitions.DroidDefinition,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Faction: "Hostile" | "Allied",
	OwnerUserId: number?,
	LastSpawn: number,
	LifetimeAt: number?,
}
export type Dependencies = {
	-- All injected callbacks are trusted synchronous ports; yielding callbacks are closed.
	Templates: Instance,
	Parent: Instance,
	Storage: Instance,
	clock: () -> number,
	random: () -> number,
	map: (number, string) -> Result.Result<Setup>,
	active: (number) -> boolean,
	players: (number) -> { Payloads.Point },
	ownerActive: (number, number) -> boolean,
	register: (Record) -> Result.Result<boolean>,
	unregister: (Payloads.EntityRef) -> (),
	lifecycle: ((string, Payloads.EntityRef) -> ())?,
}
export type Api = Domain.DroidService & {
	step: () -> (),
	records: () -> { Record },
	snapshots: () -> { DroidAI.Target },
	metrics: () -> { Alive: number, Slots: number, Cap: number, Pooled: number, PendingRespawns: number },
}
return table.freeze({})
