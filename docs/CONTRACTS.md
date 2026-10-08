# Contract catalog — draft v1

This is a planning proposal. **Contracts v1 is not frozen.** Phase 0 must implement typed definitions, validate fields/transport and supply Interface + Stub for every listed service before freeze. Owner review is required for source ambiguities and later frozen changes. See [ADRs](DECISIONS.md), [backlog](PTG-TODO-List.md), and [architecture](ARCHITECTURE.md).

The owner's latest D-01/02/05/13/16/17/18/21/26 clarifications supersede the original brief. Round and boss deadline are both240 seconds; recipient policy depends on boss identity; free spins use connected-playtime remaining seconds; only Tornado and enlarged Regular-derived bosses are implemented; lobby interactables and gems are deferred/removed. Linear-level and strongest-speed constants below are proposed tuning, not frozen values.

## Contract conventions

Draft integration update (2026-10-08): `ScenarioDirector.SelectScenario` accepts an optional validated preferred scenario for PickQueue; `DroidService.StopRound` owns round spawning/entity teardown; `DamageService.GetRoundStats` supplies server-owned MVP facts; `BossCoordinator.ObserveDeaths` exposes an owned subscription with a disconnect function. Public preview presentation includes alive IDs and results. These remain unfrozen interfaces and do not establish real combat/event/economy integration.

Data draft update (2026-10-08): internal ProfileTypes is schema1 with Revision and transaction journal. Public PlayerData currently projects SchemaVersion/UserId/Revision/Coins/TotalXP/Level/Inventory/FreeSpinRemainingSeconds/PaidSpins only; the broader planned table below is not yet implemented. Coins/TotalXP preserve bounded fractional rewards, and server-derived nonzero safe integer Studio identities are accepted. Transactions acknowledge confirmed saves, reject changed ID reuse and fence uncertainty. B-local ProfileOperations adds trusted server-only atomic mutation/boost reads; no mutation callbacks are client requests. Inventory/shop/boost operations now use that boundary, while receipt dispatch remains G-owned and unimplemented. The journal fails closed at256 entries; compaction remains unresolved.

Additional unfrozen interfaces: PlayerStateService.ReserveLobby(UserId) returns a server-only UserId/TokenId reservation; ValidateLobbyReservation checks the same Lobby character generation; ReleaseLobby is idempotent for an absent reservation and rejects a different token. A held reservation excludes eligibility/BeginRound through purchase persistence. ReplicaPublisher.PublishBoard accepts a validated public board snapshot; its injected ReplicaService wrapper targets private PlayerData only to the connected owner, with monotonic revisions and detached projections. EconomyService consumes copied source facts and injected immutable reward contexts; per-recipient durable IDs allow partial retries, but retaining/scheduling incomplete settlements remains pending. No real storage or private ReplicaService transport is enabled by these source implementations. See ADR-007 for limits.

Implementation note (2026-10-08): the owner authorized direct fixes to these unfrozen drafts. Match now exposes `PlayerStateService.EligiblePlayers/IsAfk/BeginRound/ResetRound`, `VotingService.Close`, and `GameLoopService.ReportBossDeath`, with matching safe stubs. `Close` cancels an interrupted voting window; boss reports require the current round and a planned instance ID. The Studio preview publishes public attributes temporarily; canonical replica integration remains pending. This pass establishes no contract freeze or runtime validation.

Each public service exports a typed Interface and injectable Stub. Common lifecycle: Init(dependencies), Start(), Stop(reason), Destroy(); one owner for connections/tasks, idempotent teardown, no yield at module import. Commands return typed Result values; asynchronous completion uses Promise only through the adapter and after package approval. Use stable IDs and immutable payloads; no arbitrary client-supplied Instances or callback functions.

Proposed shared types: UserId, RoundId, EntityId, DefinitionId, RequestId, TransactionId, ReceiptId; RoundContext includes RoundId, MapId, ScenarioId, participants, loadout snapshots, scoped clock/RNG and RoundScope handle server-side. MapContext exposes clone ID, validated spawn handles and recovery metadata to server interfaces; never replicate its server Instance graph.

Result<T> = success with T or failure with a stable code (InvalidRequest, UnknownId, WrongState, NotReady, NotOwned, InsufficientFunds, LimitReached, Cooldown, RateLimited, StaleRound, Unavailable). Exact serialized envelope is fixed in Phase 0; internal errors are logged, not leaked to clients.

Enums proposed: RoundState per glossary; PlayerState Lobby/InRound/Dead/Spectating; EventState Created/Starting/Running/Stopping/Stopped; DroidState Spawning/Alive/Dead/Respawning/ReturningToPool; Faction Hostile/Player/Allied; outcomes Survived/NoSurvivors/BossDefeated/BossTimeout/Aborted. Freeze table values and validate transitions.

## Typed data domains

| Type | Mandatory planning fields / constraints |
|---|---|
| GearDefinition | Id, DisplayName, Category Melee/Gun/Booster, Acquisition tagged union, UsagePolicy, BehaviorId, ToolTemplate; optional typed damage/ammo/cooldown/passives/ability |
| UtilityDefinition | Id, PriceCoins, BehaviorId, Template, CooldownSeconds, per-round use policy; effect/placement parameters typed by strategy |
| ArmourDefinition | Id, Acquisition, Stats, BehaviorId; unique ownership; Overseer admin-only |
| ClassDefinition | Id, Acquisition, Stats, BehaviorId; None is free; unique ownership |
| DroidDefinition | Id, HP, configurable XP (ordinary proposed0.2×baseHP), SpawnWeight when pool-eligible, Attack/Abilities, BehaviorTreeId, Traits, Template; proposed optional EligibleMapIds for one-file extension (R-20) |
| BossDefinition | Id, BaseDroidId=regular, HpMultiplier=50 (5000HP), configured larger rig scale (proposed2), XP override (proposed100), Template reuse; distinct EntityIds/IsBoss; no extra phases/abilities or player-count HP scaling |
| MapDefinition | Id, SpawnWeight, CoinMultiplier, XpMultiplier, DroidSpawnRate, DroidPool, Template, optional LightingProfile |
| ScenarioDefinition | Id, Weight, DroidMultiplier, RewardMultiplier, EventCount/DisasterCount ranges, BossCount |
| EventDefinition | Tornado is the only content ID; Category/eligible scenario slots, Weight, BehaviorId, typed modifiers/parameters; repeated-instance eligibility is a draft compatibility rule |
| WheelEntry | Id, Weight, typed non-gem Reward union; seven active relative weights total92, proposed normalization; historical gem8% entry disabled and excluded |
| ProductDefinition | Id, ProductId (0 guarded), ProductKind, GrantKind, configured Robux price; no invented passes |
| DialogueGraph | NpcId, EntryNodeId, Nodes/Choices, ChoiceKind, server action/condition IDs; compile owner-authored trusted hooks through adapter |
| GameConfig / PerfConfig | RoundDuration240, BossDeadline240; recipient-specific reward policy; linear XP threshold (proposed100), strongest positive speed-buff policy/base16/cap32 proposed; all remaining tunables/budgets explicit |

The source's sample `Params:any` is a starting sketch; define discriminated typed params at freeze. A strategy-specific schema is validated before any handler runs. Definitions may not embed client-callable server mutation functions. Config discovery/validation and hard-error diagnostics are a single foundation-owned registry, not one registry per stream.

Proposed droid-pool extension rule (R-20): a map's effective pool is the union of its explicit DroidPool and new definitions opting into that map through EligibleMapIds. Omitted opt-ins preserve the original three pools exactly. Validate every MapId, reject event-only definitions opting into ordinary pools, and deduplicate IDs before weighted selection. This is a draft schema proposal for Phase 0 review, not permission to change a frozen schema later.

## Service interfaces and stubs

Names are canonical proposals; internal TeleportService must not be confused with Roblox's platform service. ReplicaPublisher is the wrapper over the mandated ReplicaService library. No duplicate Logger/Replica frameworks.

| Service / module | Owner | Commands / queries | Produced facts / stub behavior |
|---|---|---|---|
| GameLoopService | A | GetState, Advance, Abort | MatchStateChanged, RoundStarted/Ended; seeded timer-driven stub cycle |
| ScenarioDirector | A | SelectScenario/Events/Bosses | ScenarioPlan; deterministic injectable RNG fixtures |
| MapService + MapValidator | A | Load, Validate, GetSpawns, Unload | MapReady/Failed; clone validated primitives |
| VotingService | A | Open, Cast, RemovePlayer, Resolve | VoteChanged, Winner; sticky ledger with seeded ties |
| PlayerStateService | A | Get/Transition, SetAfk, GetAlive | PlayerStateChanged, AliveListChanged; real lifecycle with stub eligibility |
| TeleportService (internal) | A | ToMap, ToLobby, Cancel | TeleportCompleted/Failed; safe primitive spawn fixture |
| DataService | B | OpenSession, Read, Transact, Save, Release | ProfileReady/Released; isolated in-memory nonproduction stub |
| ReplicaPublisher wrapper | B | PublishPrivate, PublishMatch, Remove | Versioned schema snapshots; deterministic fake channel |
| EconomyService | B | SettleNonBossKill/SettleBossContributors/Survival, AwardXP, QueryBalance | Currency/LevelChanged; boss single-pool/dedupe fixture and linear level derivation |
| ShopService | B | Purchase | Transaction result; reject unknown/state-invalid; stub no live writes |
| LoadoutService | C | Equip, SnapshotAndLock, Grant, Unlock/Clear | LoadoutLocked/Changed; immutable fixture selection |
| DamageService | C | Apply(source,target,base,tags), GetLedger | DamageApplied, EntityDied once; pure fixture HP/ledger |
| StatService | C | Add/RemoveSource, Resolve | StatsChanged; strongest-positive-speed resolution with independent slowdown/status layers; deterministic fixture |
| StatusEffectService | C | Apply, Remove, Clear | StatusChanged; clock-injected timed fixture |
| GearService | C | Use/Reload/Ability, Clear | GearStateChanged; validated no-op effects in stub |
| UtilityService | F | Use, GetRemainingUses, Clear | UtilityConsumed/Failed; no live consumption in stub |
| ProjectileService | C | Cast, CancelRound | ProjectileCosmetic/Hit server fact; deterministic fake cast |
| DroidService | D | StartSpawning, Spawn, Despawn, Summon, Query | DroidSpawned/Died, TargetSnapshot; fake IDs/scoped entities |
| DroidBrainHost | D | PublishSnapshot, Schedule, CollectDecisions, StopRound | Versioned BrainDecision; serial fixture executor, explicitly not parallel proof |
| EventService | E | StartPlan, StopAll, Query | EventStarted/Stopped/Failed; deterministic empty/stub events |
| BossCoordinator | E | SpawnRequired, TrackDeath, StopRound | BossProgress/AllBossesDefeated; required-count fixture |
| DestructionService | E | Explode(origin,radius,damageProfile,filter) | Explosion; no-op debris fixture behind scope |
| LeaderboardService | G | Submit, GetTop50 | BoardSnapshot; cached fake boards |
| MonetizationService | G | ProcessReceipt, QueryPass | ReceiptGrantConfirmed; fixtures only, never acknowledge fake live receipts |
| WheelService | G | RequestFreeSpin, SpendPaidSpin, CheckpointOnlineCooldown | Committed WheelResult; connected-playtime remaining clock/RNG fixture; offline pause |
| PickQueue (Monetization submodule) | G | SubmitSelection, TakeNextEligible, Restore | PickSelection; persistent-entitlement fixture |
| DialogueService | H | Open, Choose, Close | DialogueSession/Node; owner TODO graph fixture |
| QuestService | H | Accept, Progress, Complete | QuestChanged; minimal serialized fixture state |
| AdminDebugService | J | ExecuteAllowlisted | Audited debug result; disabled production stub |
| Logger / Metrics / ErrorBoundary | Foundation/J | Log, Measure, Protect | Bounded diagnostic ring buffer, counters, isolated error fixtures |
| RoundScope / Framework / Registry | Foundation | Add/Cleanup; Bind/Resolve; Discover/Validate | Canonical utilities and contract-safe boot |

Every row with a service gets an Interface + Stub, including extra internal services added to close ownership gaps. A stub may be functional enough to show the loop but must not masquerade as real persistence, payments or parallel AI. Public methods/signals and path conventions are finalized in WS-0-04/05.

## Intent remote inventory

Proposed canonical folder: ReplicatedStorage/Shared/Remotes created by gateway/adapter. Use reliable RemoteEvents for commands with RequestId and a targeted CommandResult response. No server InvokeClient. Queries should use replicas/cached facts; only a demonstrated bounded query warrants RemoteFunction. Cosmetic unreliable transport is optional and cannot carry grants/state transitions.

| Intent | Payload (client supplies intent only) | Server guards / owner |
|---|---|---|
| PurchaseItem | RequestId, Category, ItemId, Quantity | Lobby, profile ready, registered price, ownership, quantity/cap/funds, serialized transaction; B |
| EquipLoadout | RequestId, Category, ItemId, GearSlot for Gear only | Lobby, owned, allowed slot; C |
| UseGear | RequestId, RoundId, CharacterGeneration, GearSlot, paired AimOrigin/AimDirection where needed | Current participant/character, locked gear, ammo/fire rate, origin sanity/range; C |
| ReloadGear | RequestId, RoundId, CharacterGeneration, GearSlot | Current ranged gear, ammo/reload state, cooldown; C |
| UseAbility | RequestId, RoundId, CharacterGeneration, GearSlot | Registered ability, ownership, cooldown, ally cap/state; C/F |
| UseUtility | RequestId, RoundId, CharacterGeneration, UtilityId, optional Placement/Facing | Inventory count, current state, per-round limit/cooldown, placement/distance/faction; F |
| RequestFreeSpin | RequestId | Lobby/profile ready, server-connected elapsed eligibility from saved remaining seconds, one transaction; G |
| SpendPaidSpin | RequestId | Durable pending credit, atomic roll/consume; G |
| SubmitPick | RequestId, EntitlementId, MapId, ScenarioId | Owned entitlement, valid IDs, selection window, FIFO/no double consume; G/A |
| OpenDialogue | RequestId, NpcId, CharacterGeneration | Known NPC, current character/proximity, session; H |
| ChooseDialogue | RequestId, SessionId, ChoiceId, CharacterGeneration | Session/node/visibility/enabled/proximity, trusted action allowlist; H |
| CloseDialogue | RequestId, SessionId | Owned active session; H |
| DebugCommand | RequestId, CommandId, optional RoundId; no arbitrary args | Production disabled, UserId allowlist, registered command-specific checks/audit; J |

Votes are determined by server pad occupancy; no client vote-result authority. Spectate target cycling is local over the authoritative AliveList, not a mutation remote. AFK uses server zone geometry. Purchase prompts are cosmetic UX; receipt processing alone grants dev products.

Gateway validates cheap shape/type/finite checks, IDs, capped sizes and token bucket first, then permissions/state/proximity and service invariants. Each endpoint declares rate budget in config and cleans per-player limiter/dedupe state. Never accept prices, damage, result rolls, currencies, arbitrary object paths or ownership assertions. RequestIds aid correlation/replay policy but do not replace receipt durability or transaction locks.

## Signal/fact catalog

| Fact | Minimum proposed payload | Publisher → consumers |
|---|---|---|
| MatchStateChanged | RoundId, State, EndsAt, MapId?, ScenarioId? | A → B/C/D/E/I |
| RoundStarted | RoundId, immutable participants/loadout summary | A → C/D/E/B |
| RoundEnded | RoundId, SettlementId, Outcome, survivors, MVP stats | A → B/C/D/E/G/H/I |
| PlayerStateChanged | UserId, old/new state, CharacterGeneration | A → C/D/F/I |
| VoteChanged | RoundId, choices, public counts | A → I |
| DamageApplied | RoundId, DamageId, source identity/faction, target EntityId, actual HP loss, tags | C → B/D/F/H |
| EntityDied | RoundId, EntityId, DefinitionId, server IsBoss/RewardCategory, killer?, immutable actual-damage contribution summary, SettlementId | C → D/E/B/H |
| DroidSpawned/Despawned | RoundId, EntityId, DefinitionId, faction | D → E/F/I |
| BossProgress | RoundId, required IDs/count, remaining IDs | E → A/I |
| EventStarted/Stopped | RoundId, EventId, instance lifecycle ID | E → A/D/I |
| ProfileReady/Released | UserId, SchemaVersion; no public private profile | B → A/C/G/H |
| Inventory/Loadout/StatsChanged | UserId or EntityId, versioned validated delta | B/C/F → wrappers/I |
| WheelResult | RequestId, SpinId, reward summary already committed | G → targeted I |
| DialogueNode/QuestChanged | UserId, session/node/progress summary | H → targeted I |
| ProjectileCosmetic/Explosion | RoundId, effect ID, bounded position/style params | C/E → I |

Facts include generation/version where delayed application is possible. Consumers dedupe settlement/death facts, reject stale rounds and unsubscribe with their scope. Signals transport notifications; they are not alternate mutable ownership.

## Replica schemas

| Replica | Audience | Fields |
|---|---|---|
| PlayerData | Owning player only | SchemaVersion, Coins, cumulative XP, derived Level/linear progress, safe Stats, Inventory, Loadout, Wheel remaining cooldown/credit counts, Boost expiry, Quests, discovered DialogueFlags, Settings; no Gems |
| MatchState | All clients | ContractVersion, RoundId, State, EndsAt, MapId/ScenarioId, vote choices/counts, AliveList UserIds, event/boss summaries, results |
| Boards | Public cached facts | board ID, update time, Top 50 UserId/name/value entries |
| Presentation state | Narrow public/targeted attributes or batched facts | Entity HP summaries, cooldown/ammo state only to appropriate viewer; device effects remain local |

Do not replicate ProcessedReceiptIds, session locks, transaction journals, moderation/admin lists or private flags not discovered by that player. Public HP attributes are not a second damage authority. Snapshot on join and versioned deltas must handle missed packets/rejoin; UI never reads server modules.

## Persistent profile template

Proposed schema incorporates owner overrides: SchemaVersion; Coins/cumulative XP/derived Level; Stats {Kills, Assists, Damage, Survives, Rounds, DonatedRobux}; Inventory {Gears set, Armours set, Classes set, Utilities id→count ≤100}; Loadout {Gears up to3, Armour, Class}; Wheel {FreeSpinRemainingSeconds, PendingPaidSpins}; Boosts {CoinExpiresAt, XpExpiresAt}; PendingPickTokens; Quests; DialogueFlags; ProcessedReceiptIds (bounded with safe replay strategy); Settings. No active Gems field or lobby-interactable state. Runtime monotonic countdown anchors are not persisted as offline deadlines.

Free-spin clock uses only connected/profile-ready elapsed time, including lobby/AFK; save remaining time at autosave/leave/shutdown. Offline time cannot decrement it. New/reset remaining900seconds is the proposed initial/post-spin policy; paid spin credits remain independent. UI may use a transient session anchor, but server remaining time owns eligibility.

RewardPolicy is target-specific: NonBoss=KillerOnly retaining source killer-ratio truncation; Boss=ProportionalAllContributors with one fixed pool distributed by actual positive credited HP loss and no extra last-hit reward. Exclude overkill, dedupe SettlementId and specify rounding and durable disconnected grants before freeze. Do not silently truncate each boss share using ordinary D-06 logic. Boss HP scaling does not scale its XP automatically; proposed base bossXP100 is a separate config field.

Use serializable ID-keyed maps and plain values; no Instances/functions/Vector3 objects. Starting balances/default ownership are TODO(owner). Versioned migrations are deterministic/idempotent; never downgrade future schema or save a failed load. If entitlement/transaction metadata needs schema fields beyond the brief, propose those before freeze with an ADR. Define receipt compaction and durable grant proof before implementing paid features.

## Runtime AI boundary

TargetSnapshot: SnapshotVersion, RoundId, timestamp, plain target IDs/positions/velocities/factions/last-attacker facts and serial sensory/path results. BrainDecision: SnapshotVersion, RoundId, EntityId, generation, action enum plus bounded target/steering/ability params. No Instance handles cross this contract. Host rejects expired rounds, pooled/reused generation IDs and stale decisions. Worker errors return isolated diagnostics; serial host owns damage/status/MoveTo/animation.

## Freeze gate and change control

- [ ] Domain types, state enums and service interfaces compile in strict mode.
- [ ] All remote requests/responses, signals and replicas have schema/validation fixtures.
- [ ] Every service Interface + Stub participates in boot with no cyclic requires.
- [ ] Map/rig/gear templates pass validator; negative fixtures fail actionably.
- [ ] Lune tests prove pure logic; Studio proves stub loop and actual execution locations.
- [ ] Approved dependency audit, commands, boot/settings and ownership manifest are recorded.
- [ ] Format/lint/type/build/config/test gates pass; ContractVersion and approval record are recorded.

After freeze, use CCR entries in the backlog and approved ADRs. A service implementation may change behind its interface; a public shape/semantic change cannot silently bypass versioning.

## Implemented draft candidate - 2026-10-08

The executable draft lives in `src/shared/Contracts/{States,Result,Service,ServiceCatalog,Payloads,DomainInterfaces}.luau` and the per-service Interface/Stub modules. All 29 typed facade factories compile under Roblox-aware analysis. Result uses `{Ok=true,Value=T}` or `{Ok=false,Code=ErrorCode}`. Stubs always return NotReady for domain work and expose no client methods or payment acknowledgements. Common lifecycle is currently Init/Start/Stop/Destroy; BossCoordinator.StopRound is the domain command, separate from lifecycle Stop. Player transitions carry expected round and character generation; PickSelection carries MapId plus ScenarioId under one entitlement.

This candidate remains Version 0 with Frozen=false. Full runtime schema coverage, content-definition and typed signal/replica coverage, remaining mandated adapters and engine evidence are unfinished. The current EconomyTransaction is an early coin/XP envelope, not yet the complete durable inventory/receipt grant contract. The Studio harness probes actual adapter-resolved typed facades plus three primitive map fixtures and a separate clock-injected stub loop; it does not implement or prove a live match loop.

`Requests.luau` and `RequestSchemas.luau` now specify all 13 listed command payloads plus correlated boolean `CommandResult`. They reject unknown authority fields, invalid quantities/categories/generations/slots, nonfinite points, non-unit directions and metatables; validated requests own frozen copies. Categories use Gear/Utility/Armour/Class; permanent-item Quantity is 1, utility Quantity is capped at the brief's 100. Direction tolerance and field/definition limits are technical draft config. AimOrigin/AimDirection are optional as a pair; the ranged handler must require them. Utility Facing requires Placement. Debug commands require later server allowlist enforcement. No remotes or handlers are registered by these schemas.

GearService's draft Use/Reload/Ability signatures now consume their specific canonical request types. `Payloads.InputIntent`/`Schemas.inputIntent` remain legacy bootstrap fixture coverage with the old Aim field; they are not a second transport, and client Vote actions are rejected. VotingService.Cast is an internal server-zone operation.

`SnapshotSchemas.luau` validates the current minimal MatchSnapshot (ContractVersion=0, monotonic Revision, RoundId, State, optional deadline/map/scenario) and player projection (SchemaVersion, UserId, Revision, coins/XP/level, inventory, wheel clock/credits). Nested inventory copies are frozen; sparse/duplicate IDs, oversized collections, utility overflow, journals and unknown fields fail. These projections still need full planned loadout/boost/quest/vote/alive/boss/result coverage before M1. Validation does not authorize state, ownership, proximity, rate, profile readiness or durable grants.

`Framework/SnapshotBinding.luau` accepts an injected subscription, rejects stale revisions/rounds, owns unsubscribe through a detachable scope, replays late data and isolates/reports listener errors. The pure `tests/fixtures/FoundationReplica.luau` routes public versus targeted private data and rejects a recipient/UserId mismatch. It is not an adopted ReplicaService adapter. The isolated Studio harness publishes only public simulated MatchSnapshot JSON in one Attribute; its client fixture records an observed revision/state. The rapid loop can coalesce, so this proves at most observed snapshots and never all 20 live rounds. Foundation boot remains one attempt per Play VM; retrying partial Knit registration is unsupported.
