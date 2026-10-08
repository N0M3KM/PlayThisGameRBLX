--!strict
-- Draft data-only wire/domain shapes. Version 0; no contract freeze implied.
local States = require("./States")
export type EntityRef = { Id: string, Generation: number, RoundId: number }
export type Point = { X: number, Y: number, Z: number }
export type MatchSnapshot = {
	ContractVersion: number,
	Revision: number,
	State: States.RoundState,
	RoundId: number,
	EndsAt: number?,
	MapId: string?,
	ScenarioId: string?,
}
export type Inventory = {
	Gears: { string },
	Utilities: { [string]: number },
	Armours: { string },
	Classes: { string },
}
export type PlayerDataSnapshot = {
	SchemaVersion: number,
	UserId: number,
	Revision: number,
	Coins: number,
	TotalXP: number,
	Level: number,
	Inventory: Inventory,
	FreeSpinRemainingSeconds: number,
	PaidSpins: number,
}
-- Session locks and receipt history are intentionally absent from player-facing snapshots.
export type EconomyReason =
	"Kill"
	| "Boss"
	| "Survival"
	| "Shop"
	| "Receipt"
	| "Wheel"
	| "Quest"
	| "Inventory"
	| "Utility"
	| "Boost"
export type EconomyTransaction = {
	TransactionId: string,
	UserId: number,
	ExpectedRevision: number,
	Reason: EconomyReason,
	CoinDelta: number,
	XpDelta: number,
}
export type TransactionReceipt = { TransactionId: string, Revision: number, AlreadyApplied: boolean }
export type DamageRequest = {
	Target: EntityRef,
	Source: EntityRef?,
	CreditedUserId: number?,
	Amount: number,
	Faction: States.Faction,
	Kind: "Melee" | "Projectile" | "Explosion" | "Ability",
}
export type DamageFact = {
	FactId: string,
	Target: EntityRef,
	CreditedUserId: number?,
	ActualHpLoss: number,
	IsBoss: boolean,
	Lethal: boolean,
	DeathId: string?,
}
export type RoundStat = { UserId: number, Kills: number, Damage: number, Assists: number }
export type SpawnRequest = {
	DefinitionId: string,
	RoundId: number,
	MapId: string,
	SpawnId: string,
	Faction: "Hostile" | "Allied",
	BossInstanceId: string?,
}
export type TargetSnapshot = { Entity: EntityRef, Position: Point, Hp: number, Faction: States.Faction }
export type EventInstance = { InstanceId: string, DefinitionId: "tornado", RoundId: number }
export type EventPlan = { RoundId: number, Instances: { EventInstance }, BossInstanceIds: { string } }
export type BossProgress = { InstanceId: string, Entity: EntityRef, Hp: number, MaxHp: number, Dead: boolean }
export type UtilityIntent = {
	RoundId: number,
	CharacterGeneration: number,
	UtilityId: string,
	RequestId: string,
	Placement: Point?,
	Facing: Point?,
}
export type WheelClockSnapshot = { RemainingSeconds: number, ProfileReady: boolean, PaidSpins: number }
export type ReceiptInput = { PurchaseId: string, UserId: number, ProductId: number }
export type ReceiptDecision = "NotProcessedYet" | "PurchaseGranted"
export type BoardEntry = { UserId: number, Value: number }
export type BoardSnapshot = { Id: string, Entries: { BoardEntry }, UpdatedAt: number }
export type DialogueSession = {
	SessionId: string,
	UserId: number,
	NpcId: string,
	NodeId: string,
	ExpiresAt: number,
}
export type QuestProgress = {
	QuestId: string,
	ObjectiveKind: "Kills" | "Survive" | "SpendCoins",
	Current: number,
	Required: number,
}
export type InputIntent = {
	RequestId: string,
	RoundId: number,
	CharacterGeneration: number,
	Action: "Fire" | "Reload" | "Ability" | "Utility" | "Equip" | "Purchase" | "Dialogue",
	ContentId: string?,
	Slot: number?,
	Aim: Point?,
}
export type MapDescriptor = {
	Id: string,
	PlayerSpawns: { Point },
	DroidSpawns: { Point },
	DroidPool: { string },
}
export type MapContext = { MapId: string, RoundId: number, PlayerSpawns: { Point }, DroidSpawns: { Point } }
export type PlayerStateSnapshot = {
	UserId: number,
	State: States.PlayerState,
	CharacterGeneration: number,
	RoundId: number?,
}
-- Server-only reservation; holding one excludes the player from round entry.
export type LobbyReservation = { UserId: number, TokenId: string }
export type RoundOutcome = {
	SettlementId: string,
	RoundId: number,
	Reason: States.Outcome,
	Survivors: { number },
}
export type BossSettlement = { SettlementId: string, Entity: EntityRef, Contributions: { [number]: number } }
export type LoadoutSnapshot = {
	UserId: number,
	RoundId: number,
	GearIds: { string },
	ArmourId: string?,
	ClassId: string?,
}
export type StatModifier = { SourceId: string, Stat: string, Mode: "Add" | "Multiply", Value: number }
export type ProjectileRequest = {
	Source: EntityRef,
	Origin: Point,
	Direction: Point,
	GearId: string,
	ShotId: string,
}
export type BrainDecision = {
	Entity: EntityRef,
	SnapshotSequence: number,
	Action: string,
	Target: EntityRef?,
	Position: Point?,
}
export type ExplosionRequest = {
	RoundId: number,
	Origin: Point,
	Radius: number,
	Source: EntityRef?,
	RequestId: string,
}
export type WheelResult = { TransactionId: string, PrizeId: string }
export type PickSelection = {
	EntitlementId: string,
	UserId: number,
	MapId: string,
	ScenarioId: string,
}
export type QuestFact = {
	FactId: string,
	Kind: "Kills" | "Survive" | "SpendCoins",
	Count: number,
	RoundId: number?,
}
return table.freeze({ Version = 0, Frozen = false })
