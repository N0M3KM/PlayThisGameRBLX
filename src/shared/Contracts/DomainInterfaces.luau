--!strict
-- Draft typed service APIs. Freeze only after full schema review and M1 evidence.
local Service = require("./Service")
local Result = require("./Result")
local Payloads = require("./Payloads")
local Requests = require("./Requests")
local States = require("./States")

export type GameLoopService = Service.Interface & {
	GetState: (self: Service.Interface) -> Result.Result<Payloads.MatchSnapshot>,
	Advance: (self: Service.Interface, expectedRoundId: number) -> Result.Result<boolean>,
	Abort: (self: Service.Interface, expectedRoundId: number, reason: string) -> Result.Result<boolean>,
	ReportBossDeath: (
		self: Service.Interface,
		expectedRoundId: number,
		instanceId: string
	) -> Result.Result<boolean>,
}

export type ScenarioDirector = Service.Interface & {
	SelectScenario: (
		self: Service.Interface,
		roundId: number,
		preferredScenarioId: string?
	) -> Result.Result<string>,
	SelectEvents: (
		self: Service.Interface,
		roundId: number,
		scenarioId: string
	) -> Result.Result<Payloads.EventPlan>,
	SelectBosses: (self: Service.Interface, roundId: number, scenarioId: string) -> Result.Result<{ string }>,
}

export type MapService = Service.Interface & {
	Load: (self: Service.Interface, roundId: number, mapId: string) -> Result.Result<Payloads.MapContext>,
	Validate: (self: Service.Interface, map: Payloads.MapDescriptor) -> Result.Result<Payloads.MapDescriptor>,
	GetSpawns: (self: Service.Interface, roundId: number) -> Result.Result<{ Payloads.Point }>,
	Unload: (self: Service.Interface, roundId: number) -> Result.Result<boolean>,
}

export type VotingService = Service.Interface & {
	Open: (
		self: Service.Interface,
		roundId: number,
		choices: { string },
		deadline: number
	) -> Result.Result<boolean>,
	Cast: (self: Service.Interface, userId: number, roundId: number, mapId: string) -> Result.Result<boolean>,
	RemovePlayer: (self: Service.Interface, userId: number) -> Result.Result<boolean>,
	Resolve: (self: Service.Interface, roundId: number) -> Result.Result<string>,
	Close: (self: Service.Interface) -> (),
}

export type PlayerStateService = Service.Interface & {
	ReserveLobby: (self: Service.Interface, userId: number) -> Result.Result<Payloads.LobbyReservation>,
	ValidateLobbyReservation: (self: Service.Interface, reservation: Payloads.LobbyReservation) -> boolean,
	ReleaseLobby: (self: Service.Interface, reservation: Payloads.LobbyReservation) -> Result.Result<boolean>,
	EligiblePlayers: (self: Service.Interface) -> { number },
	IsAfk: (self: Service.Interface, userId: number) -> boolean,
	BeginRound: (self: Service.Interface, roundId: number, userIds: { number }) -> { number },
	ResetRound: (self: Service.Interface, roundId: number) -> (),
	Get: (self: Service.Interface, userId: number) -> Result.Result<Payloads.PlayerStateSnapshot>,
	Transition: (
		self: Service.Interface,
		userId: number,
		expectedState: States.PlayerState,
		nextState: States.PlayerState,
		expectedRoundId: number,
		generation: number
	) -> Result.Result<boolean>,
	SetAfk: (self: Service.Interface, userId: number, afk: boolean) -> Result.Result<boolean>,
	GetAlive: (self: Service.Interface, roundId: number) -> Result.Result<{ number }>,
}

export type TeleportService = Service.Interface & {
	ToMap: (
		self: Service.Interface,
		roundId: number,
		mapId: string,
		participants: { number }
	) -> Result.Result<{ number }>,
	ToLobby: (self: Service.Interface, userId: number, generation: number) -> Result.Result<boolean>,
	Cancel: (self: Service.Interface, roundId: number) -> Result.Result<boolean>,
}

export type DataService = Service.Interface & {
	OpenSession: (self: Service.Interface, userId: number) -> Result.Result<boolean>,
	Read: (self: Service.Interface, userId: number) -> Result.Result<Payloads.PlayerDataSnapshot>,
	Transact: (
		self: Service.Interface,
		transaction: Payloads.EconomyTransaction
	) -> Result.Result<Payloads.TransactionReceipt>,
	Save: (self: Service.Interface, userId: number) -> Result.Result<boolean>,
	Release: (self: Service.Interface, userId: number) -> Result.Result<boolean>,
}

export type ReplicaPublisher = Service.Interface & {
	PublishPrivate: (
		self: Service.Interface,
		userId: number,
		snapshot: Payloads.PlayerDataSnapshot
	) -> Result.Result<boolean>,
	PublishMatch: (self: Service.Interface, snapshot: Payloads.MatchSnapshot) -> Result.Result<boolean>,
	PublishBoard: (self: Service.Interface, snapshot: Payloads.BoardSnapshot) -> Result.Result<boolean>,
	Remove: (self: Service.Interface, userId: number) -> Result.Result<boolean>,
}

export type EconomyService = Service.Interface & {
	SettleNonBossKill: (
		self: Service.Interface,
		fact: Payloads.DamageFact
	) -> Result.Result<{ Payloads.TransactionReceipt }>,
	SettleBossContributors: (
		self: Service.Interface,
		settlement: Payloads.BossSettlement
	) -> Result.Result<{ Payloads.TransactionReceipt }>,
	SettleSurvival: (
		self: Service.Interface,
		outcome: Payloads.RoundOutcome
	) -> Result.Result<{ Payloads.TransactionReceipt }>,
	AwardXP: (
		self: Service.Interface,
		transaction: Payloads.EconomyTransaction
	) -> Result.Result<Payloads.TransactionReceipt>,
	QueryBalance: (self: Service.Interface, userId: number) -> Result.Result<number>,
}

export type ShopService = Service.Interface & {
	Purchase: (
		self: Service.Interface,
		userId: number,
		contentId: string,
		requestId: string
	) -> Result.Result<Payloads.TransactionReceipt>,
}

export type LoadoutService = Service.Interface & {
	Equip: (
		self: Service.Interface,
		userId: number,
		slot: number,
		contentId: string
	) -> Result.Result<boolean>,
	SnapshotAndLock: (
		self: Service.Interface,
		userId: number,
		roundId: number
	) -> Result.Result<Payloads.LoadoutSnapshot>,
	Grant: (self: Service.Interface, userId: number, roundId: number) -> Result.Result<boolean>,
	Unlock: (self: Service.Interface, userId: number, roundId: number) -> Result.Result<boolean>,
	Clear: (self: Service.Interface, userId: number) -> Result.Result<boolean>,
}

export type DamageService = Service.Interface & {
	GetRoundStats: (self: Service.Interface, roundId: number) -> Result.Result<{ Payloads.RoundStat }>,
	Apply: (self: Service.Interface, request: Payloads.DamageRequest) -> Result.Result<Payloads.DamageFact>,
	GetLedger: (
		self: Service.Interface,
		entity: Payloads.EntityRef
	) -> Result.Result<{ Payloads.DamageFact }>,
}

export type StatService = Service.Interface & {
	Add: (
		self: Service.Interface,
		entity: Payloads.EntityRef,
		modifier: Payloads.StatModifier
	) -> Result.Result<boolean>,
	RemoveSource: (
		self: Service.Interface,
		entity: Payloads.EntityRef,
		sourceId: string
	) -> Result.Result<boolean>,
	Resolve: (self: Service.Interface, entity: Payloads.EntityRef) -> Result.Result<{ [string]: number }>,
}

export type StatusEffectService = Service.Interface & {
	Apply: (
		self: Service.Interface,
		entity: Payloads.EntityRef,
		statusId: string,
		sourceId: string,
		duration: number
	) -> Result.Result<boolean>,
	Remove: (self: Service.Interface, entity: Payloads.EntityRef, sourceId: string) -> Result.Result<boolean>,
	Clear: (self: Service.Interface, entity: Payloads.EntityRef) -> Result.Result<boolean>,
}

export type GearService = Service.Interface & {
	Use: (self: Service.Interface, userId: number, intent: Requests.UseGear) -> Result.Result<boolean>,
	Reload: (self: Service.Interface, userId: number, intent: Requests.ReloadGear) -> Result.Result<boolean>,
	Ability: (
		self: Service.Interface,
		userId: number,
		intent: Requests.UseAbility
	) -> Result.Result<boolean>,
	Clear: (self: Service.Interface, userId: number) -> Result.Result<boolean>,
}

export type ProjectileService = Service.Interface & {
	Cast: (self: Service.Interface, request: Payloads.ProjectileRequest) -> Result.Result<string>,
	CancelRound: (self: Service.Interface, roundId: number) -> Result.Result<boolean>,
}

export type UtilityService = Service.Interface & {
	Use: (self: Service.Interface, userId: number, intent: Payloads.UtilityIntent) -> Result.Result<boolean>,
	GetRemainingUses: (self: Service.Interface, userId: number, utilityId: string) -> Result.Result<number>,
	Clear: (self: Service.Interface, userId: number) -> Result.Result<boolean>,
}

export type DroidService = Service.Interface & {
	StopRound: (self: Service.Interface, roundId: number) -> Result.Result<boolean>,
	StartSpawning: (self: Service.Interface, roundId: number, mapId: string) -> Result.Result<boolean>,
	Spawn: (self: Service.Interface, request: Payloads.SpawnRequest) -> Result.Result<Payloads.EntityRef>,
	Despawn: (self: Service.Interface, entity: Payloads.EntityRef, reason: string) -> Result.Result<boolean>,
	Summon: (
		self: Service.Interface,
		request: Payloads.SpawnRequest,
		ownerUserId: number
	) -> Result.Result<Payloads.EntityRef>,
	Query: (self: Service.Interface, entity: Payloads.EntityRef) -> Result.Result<Payloads.TargetSnapshot>,
}

export type DroidBrainHost = Service.Interface & {
	PublishSnapshot: (
		self: Service.Interface,
		roundId: number,
		snapshots: { Payloads.TargetSnapshot }
	) -> Result.Result<boolean>,
	Schedule: (self: Service.Interface, roundId: number, budget: number) -> Result.Result<boolean>,
	CollectDecisions: (self: Service.Interface, roundId: number) -> Result.Result<{ Payloads.BrainDecision }>,
	StopRound: (self: Service.Interface, roundId: number) -> Result.Result<boolean>,
}

export type EventService = Service.Interface & {
	StartPlan: (self: Service.Interface, plan: Payloads.EventPlan) -> Result.Result<boolean>,
	StopAll: (self: Service.Interface, roundId: number) -> Result.Result<boolean>,
	Query: (self: Service.Interface, roundId: number) -> Result.Result<{ Payloads.EventInstance }>,
}

export type BossCoordinator = Service.Interface & {
	ObserveDeaths: (
		self: Service.Interface,
		callback: (roundId: number, instanceId: string) -> ()
	) -> () -> (),
	SpawnRequired: (
		self: Service.Interface,
		roundId: number,
		instanceIds: { string }
	) -> Result.Result<{ Payloads.BossProgress }>,
	TrackDeath: (self: Service.Interface, fact: Payloads.DamageFact) -> Result.Result<boolean>,
	StopRound: (self: Service.Interface, roundId: number) -> Result.Result<boolean>,
}

export type DestructionService = Service.Interface & {
	Explode: (self: Service.Interface, request: Payloads.ExplosionRequest) -> Result.Result<boolean>,
}

export type LeaderboardService = Service.Interface & {
	Submit: (
		self: Service.Interface,
		boardId: string,
		userId: number,
		value: number
	) -> Result.Result<boolean>,
	GetTop50: (self: Service.Interface, boardId: string) -> Result.Result<Payloads.BoardSnapshot>,
}

export type MonetizationService = Service.Interface & {
	ProcessReceipt: (
		self: Service.Interface,
		receipt: Payloads.ReceiptInput
	) -> Result.Result<Payloads.ReceiptDecision>,
	QueryPass: (self: Service.Interface, userId: number, passId: number) -> Result.Result<boolean>,
}

export type WheelService = Service.Interface & {
	RequestFreeSpin: (
		self: Service.Interface,
		userId: number,
		requestId: string
	) -> Result.Result<Payloads.WheelResult>,
	SpendPaidSpin: (
		self: Service.Interface,
		userId: number,
		requestId: string
	) -> Result.Result<Payloads.WheelResult>,
	CheckpointOnlineCooldown: (
		self: Service.Interface,
		userId: number,
		connectedSeconds: number
	) -> Result.Result<Payloads.WheelClockSnapshot>,
}

export type PickQueue = Service.Interface & {
	SubmitSelection: (self: Service.Interface, selection: Payloads.PickSelection) -> Result.Result<boolean>,
	TakeNextEligible: (
		self: Service.Interface,
		roundId: number,
		connectedUserIds: { number }
	) -> Result.Result<Payloads.PickSelection?>,
	Restore: (self: Service.Interface, selection: Payloads.PickSelection) -> Result.Result<boolean>,
}

export type DialogueService = Service.Interface & {
	Open: (self: Service.Interface, userId: number, npcId: string) -> Result.Result<Payloads.DialogueSession>,
	Choose: (
		self: Service.Interface,
		userId: number,
		sessionId: string,
		choiceId: string
	) -> Result.Result<Payloads.DialogueSession>,
	Close: (self: Service.Interface, userId: number, sessionId: string) -> Result.Result<boolean>,
}

export type QuestService = Service.Interface & {
	Accept: (
		self: Service.Interface,
		userId: number,
		questId: string
	) -> Result.Result<Payloads.QuestProgress>,
	Progress: (
		self: Service.Interface,
		userId: number,
		fact: Payloads.QuestFact
	) -> Result.Result<Payloads.QuestProgress>,
	Complete: (
		self: Service.Interface,
		userId: number,
		questId: string
	) -> Result.Result<Payloads.TransactionReceipt>,
}

export type AdminDebugService = Service.Interface & {
	ExecuteAllowlisted: (
		self: Service.Interface,
		userId: number,
		commandId: string,
		roundId: number?
	) -> Result.Result<boolean>,
}

return table.freeze({ Version = 0, Frozen = false })
