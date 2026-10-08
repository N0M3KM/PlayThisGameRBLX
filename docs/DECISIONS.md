# Decision register

Baseline: 2026-10-07. Update: coding authorized 2026-10-08; Phase 0 is in progress. Source: `D:\13Games\PLAY_THIS_GAME_BRIEF.md`, superseded by the owner's nine clarifications. The owner approved remaining coding actions and asked for no repeated confirmation. Contract freeze and the Phase 0 gameplay gate still require their recorded acceptance evidence.

## Status rules

`Assumed` means an unchanged brief default, pending owner review. `Accepted` means the owner explicitly clarified that decision in this conversation. `Accepted direction; proposed tuning` means the requested behavior is confirmed, while agent-selected constants/policies need simulation/playtest and remain tunable. `Pending verification` means no current registry/API claim has been established. D-20 and D-23 are absent from the source; preserve IDs rather than renumbering.

## Source clarifications (all 24)

| ID | Conflict / missing detail | Assumed default | Planned config / location | Status / proof needed |
|---|---|---|---|---|
| D-01 | Round duration | 4 minutes = 240 seconds | Game.RoundDurationSeconds | Accepted: owner item 1; timer boundary tests |
| D-02 | Boss deadline | 240 seconds; all required bosses must die; retain 10 s early-kill celebration | Game.BossDeadlineSeconds, BossCelebrationSeconds | Accepted deadline: owner item 2; normal/boss timers coincide; outcome arbitration tests |
| D-03 | Raw addition doubles neutral multipliers | SumBonus = 1 + (map−1) + (scenario−1); preserve SumRaw/Product as strategies | Game.MultiplierCombineMode | Assumed; neutral and Baseplate fixtures |
| D-04 | Event reward multiplier undefined | Scenario.RewardMultiplier | Scenario definition | Assumed; do not apply a second event reward factor |
| D-05 | Reward recipients | Non-boss droids: KillerOnly with the source damage-ratio formula; boss deaths: share a single boss reward pool proportionally among actual damage contributors | Game.RewardPolicy.NonBoss / Boss | Accepted recipient split: owner item 3; no last-hit bonus/double payout for boss; rounding/offline contributor policy explicit |
| D-06 | Ratio precision | Floor/truncate to 2 decimals, not round | RewardCalculator | Assumed; 59.78% → 0.59 |
| D-07 | Event spawn rate undefined | Scenario.DroidMultiplier; explicit per-event modifiers multiply into cap | Scenario/Event definitions | Assumed; cap tests |
| D-08 | Droid weights exceed 100 total | Relative eligible-pool weights; Wind only through Tornado | Droid.SpawnWeight | Assumed; weighted selection tests |
| D-09 | Armour dealt-damage wording | Dealt text means DamageTaken; Overseer output ×2 is DamageDealt | Armour.Stats | Assumed; exact catalog tests |
| D-10 | Ranger melee/gun ambiguity | ×2 gun damage | Class.Stats | Assumed; melee unaffected |
| D-11 | Ammo Box target | Equipped ranged gear; +1 magazine reserve, Ranger ×2 | Utility behavior | Assumed; every class permitted |
| D-12 | XP, blast/turret/boss/ability tuning absent | Config placeholders with TODO(owner), never invent final balance | Respective definitions | Assumed; missing-value inventory below |
| D-13 | Free-spin countdown persistence | Persist remaining cooldown; decrement only during connected, profile-ready playtime, including lobby/AFK; pause entirely offline; restore remaining time on rejoin | Wheel.FreeCooldownSeconds = 900; profile Wheel.FreeSpinRemainingSeconds | Accepted online-only clock: owner item 4; server elapsed time, leave/autosave/shutdown checkpoints and no offline accrual |
| D-14 | Duplicate wheel unique gear | Coin compensation, owner-tunable amount | Wheel.DuplicateCompensation | Assumed; amount TODO(owner) |
| D-15 | Paid map/event pick semantics | 69 Robux Pick Token chooses map + scenario; next eligible round; FIFO, one per round | Products.PickToken, PickQueue | Assumed; entitlement retention tests |
| D-16 | Event/boss scope | Implement Tornado only. Boss reuses Regular Droid behavior/damage/cadence, has 50×HP (5000), and a larger rig. No extra event content, boss phases/abilities or player-count HP scaling | Boss.HpMultiplier = 50; proposed Boss.ScaleMultiplier = 2; repeat-Tornado policy below | Accepted scope/HP: owner item 5; scale factor and repeated-instance policy are proposals |
| D-17 | Chair/sofa/obby ownership | Remove all agent-authored chair/sofa/obby logic, assets, purchases and tests from scope; owner designs these later | No LobbyInteractable service/config/remotes in v0.1 | Accepted: owner item 6; preserve existing owner content if encountered |
| D-18 | Gems scope | Defer gems entirely: no active gem currency field, UI or grants; historical 8% wheel entry is reserved/disabled pending wheel-policy resolution | Gems feature deferred; proposed active wheel weight sum = 92 | Accepted deferral: owner item 7; seven-entry normalization is proposed, not a new approved reward |
| D-19 | Placeholder UI vs no design | Bare functional primitives only | UI shells | Assumed; owner approves styling separately |
| D-21 | Leveling curve | Linear leveling, fixed XP per level; proposed 100 XP/level, ordinary droid XP = 0.2×base HP, boss base pool XP = 100 override | Game.Leveling.XpPerLevel; Droid.XP; Boss.XP | Accepted linear/balancing direction: owner item 8; constants are proposed and require pacing tests |
| D-22 | Utility cap behavior | Buy blocked at 100; grants clamp to 100 | Game.UtilityCap | Assumed; cap/overflow tests |
| D-24 | Utility inputs | Separate actions from 3 gear slots | Input config | Assumed; touch/gamepad coverage |
| D-25 | Late join/rejoin policy | Lobby + spectate; no mid-round restoration | PlayerState policy | Assumed; no second reward eligibility |
| D-26 | Speed stacking too strong | Proposed strongest active positive multiplier (not a product); cap resolved WalkSpeed at 32 studs/s with provisional base 16. Ghost/Coil/Cola do not multiply each other | Game.SpeedBoostCombineMode = Strongest; Game.WalkSpeedHardCap = 32 | Accepted nerf direction: owner item 9; stack policy/base/cap are proposals; slower effects handled separately |

## Owner clarification details and tuning proposals

The nine items above supersede the original brief. Do not revert to a 180-second boss deadline, offline wall-clock spin countdown, universal KillerOnly rewards, multiple event content stubs, extra boss mechanics, lobby interactable implementation, active gems, nonlinear leveling or ×12 speed stacking. [Task threads](TASK-THREADS.md) record the requested grouped subthreads.

### Reward and leveling model

Proposed linear model: `Level = 1 + floor(TotalXP / 100)`; next-level XP is `100 - (TotalXP % 100)`. Persist cumulative XP; derive level server-side. Ordinary base XP proposals: Regular 20, Chaser 20, Range 10, Wind 20, Noob 60, Worker 30, Police 24 (0.2×their base HP). Bosses have 5000 HP but a separate proposed base reward pool of 100 XP, avoiding an unintended 50×XP windfall.

Existing map/scenario factors, damage-ratio truncation and personal boosts still apply. A sole-contributor Regular kill on a neutral map/Regular scenario gives 20 XP, so five such kills advance one level; Baseplate gives 25 XP, so four advance one level. Neutral Big Boss scenario gives a 175 XP boss pool before personal boosts; a 50% contributor gets 87.5 XP before quantization. Each It's Over boss has a 300 XP pool; recipients split each pool by actual damage. These are analytical starting fixtures, not a claim of tested balance. Simulate team sizes/kill rates and playtest before finalizing thresholds/rewards. Retain literal KillCoins behavior from R-04 until separately resolved.

Non-boss killer-only rewards keep the brief's killer damage ratio; the owner clarified recipient policy, not explicitly that the killer receives a full non-boss reward regardless of contributions. For a boss, sum actual credited HP loss per participant and share once at death; no duplicate killer payout. Keep reward shares full precision internally until an explicit settlement quantization rule, rather than applying ordinary truncation to each boss share and silently shrinking its pool. Proposed disconnected-contributor policy: preserve ledger identity, defer durable award by settlement ID until a safe profile session is available; implementation must not blindly open a competing locked profile.

### Online-only free-spin time

Persist `FreeSpinRemainingSeconds`, not a wall-clock `NextFreeSpinAt`. Use server monotonic elapsed time for the current connected/profile-ready session, checkpoint on autosave/leave/shutdown, and reload unchanged after any offline interval. New-profile and post-successful-spin initial cooldown is proposed at the existing 900 seconds. Count lobby and AFK time because the player is still in-game. Failed/unloaded profiles never overwrite saved progress. Concurrent free-spin requests atomically reserve eligibility/reset; paid credits do not silently reset the free timer. UI may receive a session-only countdown anchor for display, but it is not durable eligibility authority.

### Tornado, boss and deferred-content boundaries

Preserve the five scenario weights/counts as far as possible. Proposed compatibility rule: regular Event/Disaster slots resolve to independently scoped instances of Tornado (the only implemented content), including 2–3 slots where required. This category eligibility and repeat policy is not an explicit owner choice; review before contract freeze. Aggregate droid/effect/force budgets still apply; multiple Tornado instances cannot multiply unbounded forces or exceed global caps. Alternative is revising scenario counts with owner approval; do not silently invent other content or reduce counts.

Bosses reuse Regular chase/melee AI, 5 damage per 1 second, and traits; HP is confirmed at 100×50 = 5000. Proposed uniform rig scale is 2, validated for joints/root/attachments/spawn clearance/path dimensions. One or two boss instances have distinct runtime IDs under the unchanged scenarios. No extra phase machinery, ranged attacks or count-dependent HP scaling is required.

Gems are not implemented. Preserve the old +5 Gems/8% entry only as historical reserved content. Proposed playable wheel draws among the seven other unchanged relative weights totaling 92, normalizing by 92; it neither grants gems nor invents a replacement prize. Because this alters effective odds, final wheel probabilities remain a flagged economy decision before live enablement.

### Speed nerf

Proposed resolution separates positive buffs from slowdown/status layers: `buffMultiplier = max(1, active positive speed multipliers)`; apply base speed and independent slows, then cap at 32 studs/s. With proposed base16, Coil×2 or Cola×2 gives32; Ghost×3 also caps32; Coil+Cola+Ghost remains32. Stun still resolves to zero and buff removal recomputes from remaining sources. Purchase prices and individual source definitions remain unchanged. Test usability/value of Ghost, slow/boost order and near/far AI under the nerf before adopting final tuning.

## Additional risks and interpretations

| ID | Proposal / unresolved issue | Consequence and affected task |
|---|---|---|
| R-01 | Retain existing Aftman and acceptable ProfileService; wrap persistence | No manager/library replacement without approval; WS-0-02/03, WS-B-01 |
| R-02 | Damage ledger credits actual positive HP loss; exclude overkill; sole damager ratio = 1 | Clarify rounding, contributor eligibility, environmental/ally kill attribution before RewardCalculator freeze; WS-0-04, WS-B-04, WS-C-01 |
| R-03 | Bounded receipt IDs cannot permit replay after pruning | Define durable compaction/replay protection with crash/retry fixtures before monetization gate; WS-G-01/02 |
| R-04 | Source KillCoins = KillXP / 2 inherits XP multipliers/boost before coin boost | Preserve literal formula until approved otherwise; make inheritance and currency fractional quantization explicit before freeze; WS-B-04 |
| R-05 | Regular-derived boss can instantiate twice with distinct identities | It's Over still requires both dead; HP5000, same behavior, larger rig; never reduce boss count to one; WS-E-04 |
| R-06 | Existing scenario slots with Tornado-only content | Proposed repeated scoped Tornado instances and explicit Event/Disaster eligibility; no other stubs or silent count reduction; WS-E-03 |
| R-07 | Proposed contract conventions and asset hierarchy | All draft, not frozen; validate names, fields, enum wire values, paths and hooks in WS-0-04/08 |
| R-08 | Parallel worker Instance-free plan versus raycast perception | Precompute/budget serial sensory input unless a documented worker API exception is approved; verify thread safety, stale snapshots; WS-D-03/04 |
| R-09 | Lune cannot prove engine physics/Actors/real network behavior | Separate pure/mocked and Studio runners; demonstrate chosen test-library compatibility; WS-0-09 |
| R-10 | Data-only extensibility only covers registered strategies | Recipes prove no core edits for existing mechanics; new mechanics get a separate strategy task, not an implicit exemption; WS-J-07 |
| R-11 | Timing tie between boss death, deadline, everyone-dead | Use single serialized resolution and explicit event ordering; define survivors at celebration end as brief states; WS-A-01/06 |
| R-12 | AFK/free-spin time and zero eligible players | Connected lobby/AFK playtime counts; offline pauses; loaded-profile clock and zero-participant round remain safe; WS-A-04, WS-G-03 |
| R-13 | Donation receipt lacks trusted purchase price from UI | Approved ProductId→configured Robux mapping only; reconcile mapped ID/price before live enablement; WS-G-02/05 |
| R-14 | Utility consumption then placement/persistence failure | Per-profile transaction/reservation and explicit rollback/refund; no free effects or lost units; WS-F-01 |
| R-15 | Warm pools and persistent Actors change global counts | Soak compares steady warmed baseline and round-owned resource zero; record count categories; WS-J-04 |
| R-16 | Product IDs, gamepass entitlements and owner assets unavailable | Use zero-ID guards and primitive templates; live purchase enablement/content authoring separate from v0.1 plumbing; WS-G-06 |
| R-17 | Existing weather examples are user-authored and not boot-wired | Preserve files; do not activate Rainy/Snowy as new event content under Tornado-only scope; inspect reusable lifecycle infrastructure; WS-0-01/07 |
| R-18 | Default loadout/new-player balances, assist threshold/MVP ties, draw insufficient maps undefined | Put safe non-economy fallbacks in config; economy placeholders remain marked; owner review before affected contract freeze; WS-0-04, WS-A-02/06, WS-B-02 |
| R-19 | Boost duration, boss settlement and pending-pick policies | Boss sharing is required, not optional fallback; document settlement precision/durable disconnected grants and duration/token lifecycles; WS-B-04/05, WS-G-03/04 |
| R-20 | Explicit Map.DroidPool lists would require a second config edit to activate a new droid | Propose optional DroidDefinition.EligibleMapIds with validated IDs; effective pool unions explicit Map.DroidPool and definition opt-ins. Existing seven definitions retain the exact source pools. Review before freeze in WS-0-04/06; prove a new file plus rig enters an existing map in WS-J-07 |

## Missing tuning register

Boss HP5000 and Regular-equivalent behavior/damage are owner-confirmed. XP/level/speed/rig-scale starting values above are agent proposals under the requested balancing direction. Remaining unset values: gun fire/reload/range parameters absent from the brief; landmine damage/radius; turret damage/range/fire rate; shock-gun range; Wind cooldown; knockback/lunge movement/ragdoll timing; balloon jump; allied cap/lifetime; follower turret; spawn minimum distance; duplicate compensation; starting currencies/loadout; purchase durability timing; retry/autosave; network/rate/AI/performance/debris limits. Do not pass provisional fixtures off as tested or owner-approved constants.

## ADR queue

| ADR | Scope | Current status | Required evidence |
|---|---|---|---|
| ADR-001 | Preserve/migrate existing Rojo and weather scaffold | Proposed | Ownership inventory, no duplicate boot paths, migration diff |
| ADR-002 | Tool manager/pins and reproducible locks | Pending verification | Current upstream releases, CLI syntax, Wally resolution, registry/lock reconciliation; correct ignore rules |
| ADR-003 | Package audit: Knit adapter, ReplicaService, persistence, FastCast, zones, utilities, test framework | Pending verification | Primary registry/repository URLs, check date, version/license/maintenance, transitive graph, owner approval for additions/replacements |
| ADR-004 | Contracts v1 and stub behavior | Proposed | Typed interfaces, schema fixtures, signal/remotes/replica catalog, code review and passing gate |
| ADR-005 | Place settings: streaming, character rigs/auto-load, lighting, kill heights | Proposed | Studio/Rojo support verification, device and respawn tests; keep current values until adopted |
| ADR-006 | Parallel AI/API safety and serial query budgets | Source/API audit checkpoint; runtime/perf gate open | Actor probe, perf/staleness/failure tests |
| ADR-007 | Profile transactions/receipt durability and compaction | Proposed | Session-lock/save API audit, replay/crash tests, approved durability policy |
| ADR-008 | Recipient-specific rewards, linear leveling and speed nerf | Accepted direction; proposed tuning | D-05/21/26 owner clarifications, pacing simulation, boss shares/quantization and strongest-buff fixtures |
| ADR-009 | Tornado-only selection and Regular-derived bosses | Accepted scope; proposed compatibility/scale | Repeated-instance eligibility/counts, aggregate caps, HP5000, larger rig validation and two-boss fixture |
| ADR-010 | Headless/Studio testing and performance baseline | Proposed | Test-library adapter proof, toolchain checks, representative hardware measurements |
| ADR-011 | Input/device and UI placeholder scope | Proposed | CAS mappings, functional semantics, all-device evidence, no unapproved visual design |

No package/API maintenance verification was performed for this documentation-only task. Existing versions are local observations, not current upstream recommendations. Verification happens before adopting packages or worker APIs.

### ADR-007 - B transaction and settlement implementation checkpoint

Status: Proposed durability policy; source implemented behind injected adapters. This does not close live persistence acceptance.
Date / owner / related tasks: 2026-10-08 / foundation integration lead and WS-B task agents / WS-B-01 through08, WS-A-08, future WS-G-03/04.
Context: granting before confirmed storage can duplicate purchases/rewards; a failed confirmation may still have persisted. Offline recipients must not trigger competing profile loads. Existing ProfileService remains mandated/acceptable; no additional package was adopted.
Options considered: acknowledge in-memory mutation; retry uncertain writes blindly; acknowledge only a confirmed candidate and retain stable per-target identities. For journal capacity, unsafe deletion was rejected in favor of failing closed until a replay-safe compaction policy exists.
Decision: DataService owns candidate copies and confirmation; failure fences the session. Charge/grant/stats/journal changes share one profile write. FIFO operations retain immutable command identities; guards/mutators cannot yield. Shop holds a server-only Lobby reservation through queue/save, excluding round entry. Profile locks remain owned until HopReady; shutdown drains loads, saves and explicit releases within its deadline. Retry only safe load failures, at most three attempts. Optional budget and aggregate metrics are injected policies, not verified DataStore budget behavior.
Settlement: source facts are copied before context-provider yields. Provider owns reproducible immutable tuning/boost/contribution snapshots. Ordinary rewards target the credited killer; bosses share one pool; survival records rounds for all participants and survival/coins for eligible survivors. Stable source/recipient IDs and semantic fingerprints reject changed retries. Partial failure returns failure and skips confirmed recipients on retry. Current callers must retain the source and retry; no automatic or durable offline delivery queue exists, and A currently only reports failed settlement. Do not claim these pending payouts will survive shutdown.
Config/contracts and migration: draft v0 adds server-only Lobby reservation methods, PublishBoard and B-local ProfileOperations; no client can supply mutation callbacks. Profiles reconcile schema0/missing fields to1, reject future/corrupt data and remove legacy Gem fields. Fractional coins/XP preserve current reward formulas; no final quantization policy is adopted. Boost durations/multipliers are injected; expiry extends from max(now, saved expiry). The transaction journal fails closed at256 unique entries; receipt pruning/compaction remains unresolved. Technical retry/queue/autosave defaults remain provisional tuning.
Verification source/date: authored implementation and injected memory Studio checks on2026-10-08; existing package API audit remains ADR-003. No new upstream package/provenance claim, dependency install, live DataStore experiment or real ReplicaService delivery was performed. Prepared regression files were statically checked but not executed under the owner exception. Real rejoin/server-close, multi-client private delivery, replay/crash, offline payout retention and compaction remain acceptance requirements.
Consequences: confirmed target retries are idempotent and uncertainty fails closed, but journal exhaustion and missing durable pending settlement delivery limit readiness. Boot remains stubbed until dependencies/integration gates are met.
Owner approval evidence: owner's task-specific A-to-B implementation/subagent authorization and direct fixes to unfrozen contracts; no final economy tuning or dependency addition inferred. Commit/push authorization is covered by AGENTS.md and applies on workstream completion.
Supersedes: none; supplements ADR-003/008 without freezing contracts.

### ADR-006 - Bounded Actor workers and serial actuation

Status: Proposed implementation checkpoint; documented API boundaries verified, Studio worker/performance acceptance remains open.
Date / owner / related tasks: 2026-10-09 / WS-D-03/04 Actor scheduler agent and foundation integration lead.
Context: droids must not create individual Actors or Heartbeat connections. Pure brains need current-generation facts without owning live Instances; callbacks may arrive after a round ends, respawn occurs or a worker fails.
Options considered: one Actor per droid; one serial brain loop; a bounded stable-partition Actor pool with immutable shared snapshots. Decision: four configurable worker Actors, at most one pending job per worker, configurable bounded batches/pending count and fair near/mid/far scheduling. Root owns the single serial heartbeat and all world queries/actuation. Stable entity-ID hashing preserves blackboard ownership. Each worker pre-requires pure brain/codec modules in serial, decodes its recursively frozen SharedTable frame, computes decisions in BindToMessageParallel, then calls task.synchronize before firing its owned BindableEvent. No Instance query/property mutation, require, physics or pathfinding runs in the parallel callback. Removed/replaced generations are evicted from worker-local brains on the next batch; stopping a round destroys the whole pool, its result connections and pending/completed mailboxes.
API-by-API audit: Actor.SendMessage supports asynchronous cross-Actor messages and SharedTable arguments; BindToMessageParallel starts the callback in parallel. SharedTable construction, scalar/nested SharedTable reads, cloneAndFreeze and ordinary Luau table/math operations provide the immutable data path. task.synchronize switches to serial before BindableEvent.Fire; BindableEvent creation, event binding, Script enabling, parenting and Actor destruction are confined to serial host/worker initialization/cleanup. Parallel require is explicitly disallowed by the platform guide, so all requires precede binding. The implementation does not depend on parallel Instance reads, raycasts or PathfindingService thread-safety claims.
Config/contracts and compatibility: Draft DroidAI.Frame carries round, monotonic sequence, generation, finite positions/HP, bounded agent/target lists, abilities and visibility facts. DroidBrainHost retains canonical commands and adds C/D-local configureFrame and metrics methods. Schedule's budget is milliseconds, clamped to the configured serial scheduling budget; the worker compute duration is measured separately and cannot be preempted by that budget. LOD distances/intervals and worker bounds are provisional technical policy, not owner-approved game balance. No dependency or frozen contract changed. Canonical PublishSnapshot updates targets after a full frame has been configured; callers needing abilities/visibility use configureFrame.
Failure/security/cleanup: results must match their pending job round/sequence and current entity generation; collection rechecks generation and round. Serial actuation must independently check live identity, target, range, faction, cooldown and state, including after worker replacement loses its local cooldown state. Watchdogs replace stuck/unready workers only up to the configured retry limit; an exhausted partition fails closed for the rest of the round. Frame serialization rejects cycles, Instances/functions, nonfinite scalars and excess nodes. Actor crash packets and timeouts remain isolated to their partition. Average compute time is cumulative; P95 is the latest 128 returned batch timings. ParallelBatches counts actual worker responses rather than scheduled jobs. These timings include worker-local snapshot decoding and decision/encoding, and exclude messaging delay/serial actuation. Serial snapshot construction and scheduler query caps require measured load acceptance; configured bounds alone do not prove frame budget compliance.
Primary verification URLs, checked 2026-10-09: [Actor methods](https://create.roblox.com/docs/reference/engine/classes/Actor), [SharedTable](https://create.roblox.com/docs/reference/engine/datatypes/SharedTable), [Parallel Luau model, require restrictions and thread safety](https://create.roblox.com/docs/scripting/multithreading). Observed documentation is the current platform documentation; no engine version/pin claim is made.
Tests and measurable acceptance: prepared deterministic scheduler tests cover count/fairness, all LOD intervals, denied worker capacity, generation replacement, CPU deadline and empty input. No unit suite was executed under the owner's exception. Integration lead must verify actual workers/parallel responses, latest-generation rejection, bounded restart/exhaustion, round-stop zero owned Actors/mailboxes and measured average/P95 at configured caps. Mock decisions cannot close those requirements; no Studio evidence is claimed by this ADR.
Owner approval evidence: explicit continuation through D with task-specific subagents and authority to fix draft contracts; existing owner exception skips unit-suite reruns/evidence-file entries. No new package adoption, final tuning, or acceptance closure is inferred.
Supersedes: supplements the ADR-006 planning placeholder; does not close its runtime/performance gate.

## ADR template

```markdown
### ADR-nnn — Title
Status: Proposed | Accepted | Superseded
Date / owner / related tasks:
Context and constraints:
Options considered:
Decision and rationale:
Affected config/contracts and compatibility/migration:
Primary verification URLs, checked date, observed version/status:
Security/performance/cleanup implications:
Tests and measurable acceptance:
Owner approval evidence (required where applicable):
Supersedes / superseded by:
```

### ADR-012 - Approved local development toolchain

Status: Accepted for developer tooling; broader runtime dependency ADRs remain Proposed.
Date / owner / related tasks: 2026-10-08 / foundation lead / WS-0-02, WS-0-09.
Context: missing formatter/linter/type/test binaries; Aftman attempted installation twice but its global Rojo alias was locked.
Options: retry/replace global aliases; migrate tool managers; install exact official release binaries locally.
Decision: keep Aftman and existing root pins, record development pins in `tools/toolchain/aftman.toml`, and use the local archive installer. No global processes are stopped and no package manager is replaced.
Impact: ignored tool binaries/typedefs/build artifacts under `tools/toolchain/bin`; `.luaurc` points to local generated Lune definitions. Wally manifests/lock are no longer ignored, but registry/lock reconciliation remains unfinished. No runtime contract/economy change.
Verification: official release assets and pinned license files checked 2026-10-08; local version commands, installer replay, formatter/linter/type checks, tests and Rojo build passed. StyLua2.5.2, Selene0.31.0, Lune0.10.5 are MPL-2.0; Luau LSP1.70.1 is MIT. Sources: [StyLua license](https://raw.githubusercontent.com/JohnnyMorganz/StyLua/v2.5.2/LICENSE.md), [Selene license](https://raw.githubusercontent.com/Kampfkarren/selene/0.31.0/LICENSE.md), [Lune license](https://raw.githubusercontent.com/lune-org/lune/v0.10.5/LICENSE.txt), [Luau LSP license](https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.70.1/LICENSE.md); exact release links in [evidence](evidence/PHASE-0-START.md). Binary release transitive build dependencies are not adopted as Roblox runtime packages.
Consequences: Windows local setup is verified; other platforms need their own assets and evidence. Generated tool files are not game source. API execution in Studio and remaining mandated libraries are separate gates.
Owner approval: specific installation approved, followed by 'approve all the action' / 'yes to every action' / 'stop asking for approval. keep going' in this conversation on2026-10-08.
Supersedes: none; supplements ADR-002/003 without claiming their runtime audits complete.

### ADR-003 - Existing package audit checkpoint

Status: Partially verified; remaining additions, provenance and adapter proofs pending. No replacement or new package adopted.
Date / owner / related tasks: 2026-10-08 / foundation lead, read-only Group02 audit / WS-0-02/03, WS-B-01, WS-G-01.
Context: existing generated Packages/ServerPackages and Wally lock already contain Knit1.7.0, ProfileService1.1.0 and transitive packages. Maintenance, identity and license evidence must precede M1. The archive/unsupported status of mandated libraries does not authorize migration.
Options considered: retain exact existing graph behind adapters; replace mandated libraries; adopt additional libraries after concrete approval. Decision: preserve current files/pins and record risks; root uses Knit only behind its existing adapter and keeps all profile/payment execution disabled. New pins and replacements remain separate approval actions.

Verified existing graph and license declarations:

| Pin | Identity/license evidence | Maintenance observation |
|---|---|---|
| sleitnick/knit1.7.0 | [Release](https://github.com/Sleitnick/Knit/releases/tag/v1.7.0), [registry](https://github.com/UpliftGames/wally-index/blob/main/sleitnick/knit); MIT | [Upstream](https://github.com/Sleitnick/Knit) archived July 31, 2024; no further updates planned |
| firebird702/profileservice1.1.0 | [Registry](https://raw.githubusercontent.com/UpliftGames/wally-index/main/firebird702/profileservice): server realm, fork, Apache-2.0, no dependencies | Exact fork repository/commit and fork maintenance unverified; metadata supplies no repository URL |
| sleitnick/comm1.0.1 | [Registry](https://raw.githubusercontent.com/UpliftGames/wally-index/main/sleitnick/comm), [official module](https://github.com/Sleitnick/RbxUtil/blob/main/modules/comm/wally.toml); MIT | [RbxUtil history](https://github.com/Sleitnick/RbxUtil/commits/main/) shows activity in July 2026; repository activity is not a module-support guarantee |
| evaera/promise4.0.0 | [Release](https://github.com/evaera/roblox-lua-promise/releases/tag/v4.0.0), [pinned license](https://github.com/evaera/roblox-lua-promise/blob/v4.0.0/LICENSE), [registry](https://raw.githubusercontent.com/UpliftGames/wally-index/main/evaera/promise); MIT | [Visible history](https://github.com/evaera/roblox-lua-promise/commits/master/) last shows October 2023 activity at this audit |
| sleitnick/signal2.0.3 | [Registry](https://raw.githubusercontent.com/UpliftGames/wally-index/main/sleitnick/signal), [official module](https://github.com/Sleitnick/RbxUtil/blob/main/modules/signal/wally.toml); MIT | Same RbxUtil observation |
| sleitnick/option1.0.5 | [Registry](https://raw.githubusercontent.com/UpliftGames/wally-index/main/sleitnick/option), [official catalog](https://github.com/Sleitnick/RbxUtil); MIT | Same RbxUtil observation |

Knit's ranges allow Comm>=1,<2 and Promise>=4,<5; Comm allows Option>=1,<2, Promise>=4,<5 and Signal>=2,<3. The local exact graph matches those registry requirements. ProfileService, Promise, Signal and Option declare no further packages. Installed ProfileService resembles [MadStudioRoblox/ProfileService](https://github.com/MadStudioRoblox/ProfileService), whose upstream is unsupported; this observation does not establish firebird702 fork provenance.

The preliminary concern about `registry="test"` is resolved: [Wally0.3.2 lockfile code](https://github.com/UpliftGames/wally/blob/v0.3.2/src/lockfile.rs) writes that literal and omits package checksums. Do not manually edit the generated lock. Package identity/version/graph reconciliation passed; clean-install reproducibility and artifact/source provenance remain unproven. Reproducible manifest/lock tracking is still required.

Pending identities, not adoption decisions: [ReplicaService](https://github.com/MadStudioRoblox/ReplicaService) is Apache-2.0 and upstream unsupported; exact approved artifact/hash and adapter proof pending. [FastCast author docs](https://etithespir.it/FastCastAPIDocs/) establish author/API identity, but exact pin/license/transitives/maintenance remain unverified. [ZonePlus](https://github.com/1ForeverHD/ZonePlus) and [t](https://github.com/osyrisrblx/t) identify MIT sources; approval/pins/registry reconciliation remain pending. [RbxUtil](https://github.com/Sleitnick/RbxUtil) lists TableUtil1.2.1 as a candidate, not an approved pin. [TestEZ](https://github.com/Roblox/testez) identifies Apache-2.0 and Roblox/Lemur use; Lune compatibility requires execution proof. No successor package or guessed repository is silently adopted.

Contract/config impact: none frozen; all contracts remain v0. Future DataService/receipt contracts must distinguish application from durable confirmation. Installed ProfileService documentation describes MetaTagsLatest/MetaTagsUpdated as saved metadata evidence; its non-yielding Save call alone cannot acknowledge PurchaseGranted. Atomic inventory grants, receipt replay/crash behavior and release-during-save tests remain M1/G prerequisites.
Consequences: accept existing-library maintenance risk only within the mandated scope; isolate adapters, resolve fork provenance and complete clean reproducibility/addition audits. Current pure/Studio fixtures cannot prove live persistence or package maintenance.
Verification date: 2026-10-08; primary URLs above plus local manifests/lock inspected. Tests: dependency graph inspection and existing foundation checks passed; no package install, clean replay or live data experiment performed during this audit.
Owner approval evidence: existing Knit requested and ProfileService acceptable under brief/AGENTS.md; owner reaffirmed source coding/subagent review. This is not approval for new package pins or replacements.
Supersedes: Group02's preliminary lock-registry defect interpretation; supplements ADR-002/012 without freezing contracts or closing M1.
