# Validation and evidence plan

Status: planned; **no gameplay tests were run as part of writing these documents**. Task checks/evidence are recorded in [backlog](PTG-TODO-List.md). Headless test results and Studio/hardware results are separate.

## Harness boundaries

| Layer | Proposed harness | What it proves |
|---|---|---|
| Static | StyLua, Selene, Luau LSP, Rojo, schema/link validation | Formatting, lint/types, mappings, config references |
| Pure unit | Lune runner with verified Jest-Lua/TestEZ-compatible adapter | Injected clocks/RNG, formulas, FSMs, ledger/ammo/validation |
| Mock integration | Lune fixtures and interface stubs | Service orchestration, transactions/failure ordering; not engine behavior |
| Studio integration | Play + Server & Clients (at least 2) | Execution location, remotes/replicas, physics, Actors, character/round lifecycle |
| Data/marketplace integration | Isolated test universe, sanitized IDs/namespaces | Real session persistence/shutdown and authorized receipt test flow |
| Devices/perf | Device/controller emulators plus representative low-end mobile hardware | Inputs/layout plumbing; hardware required for claimed 60 FPS |
| Soak | Studio automated ≥20-round loop with resource tracker | Leaks/stale jobs under recurring real lifecycle |

Test filenames: planned `*.spec.luau`, grouped by domain under tests/unit and tests/integration. Headless runners discover only compatible modules; Studio-only specs are explicitly tagged/separate. No test framework or runners currently exist. No coverage percentage is invented; critical invariants and edge cases below must have evidence.

## Required pure logic cases

- WeightedRandom: seeded repeatability, relative nonnormalized weights, zero/negative/NaN rejection, 3 maps without replacement, uniform tie-break, documented sampling confidence/tolerance rather than flaky exact frequency assertions. Provisional wheel uses exactly seven active weights summing 92, samples `weight/92`, never selects the historical disabled gem reward, and rejects an all-disabled pool.
- RewardCalculator: neutral SumBonus=1, alternative policy strategies, Baseplate XP 1.25/coin1.5, non-boss KillerOnly truncation 0.5978→0.59, sole contributor1.00, partial/overkill attribution, no duplicate death/survival payout, boost inheritance and quantization. Boss policy allocates one base pool proportionally by actual positive damage; final-hit ownership gives no special share. Test 60/40 splits, ledger-order independence, zero/nonpositive damage, overkill, one or two independent boss pools, and contributor disconnection/environmental/ally attribution under the finalized policy. Sum of unboosted shares equals the pool before quantization; rounding residuals cannot mint or duplicate rewards.
- RoundStateMachine: legal/illegal transitions; Active duration exactly 240 seconds (D-01); boss deadline exactly 240 seconds from Active entry (D-02), including one alive boss in the two-boss case; early/all-boss defeat and 10-second celebration; everyone dead, simultaneous outcomes, stale callback, empty server, failed load/teleport and watchdog recovery. Boundary fixtures at 239.999/240 must exercise documented ordering for death-versus-deadline ties.
- AmmoModel: initial 1/5,30/60,50/150; empty fire, finite reserves, reload interruption, Ammo Box +magazine, Ranger ×2 and every-class acceptance.
- CooldownTracker: injected clock, exact expiry, per-player/per-round isolation, cleanup and reconnect reset policy.
- StatModifier: additive/multiplicative layers/source removal for other stats; Warrior HP, three vests; proposed strongest-positive speed multiplier and 32-stud/s cap under a 16-stud/s baseline (D-26). Coil32, Cola32, Coil+Cola32, Ghost32, all three32; expiry/removal recomputes remaining sources, and no boosts restores16. Test duplicate source rejection, duration refresh policy, Ghost transparency cleanup, stun overriding boosts, death/respawn cleanup and invalid multiplier/cap config. Numeric fixtures track provisional tuning, not finalized owner-approved constants.
- DamageLedger: actual HP lost, source faction, duplicate death, assists/MVP, disconnected contributor and invalid values.
- ConfigValidator: missing fields, duplicate/unknown IDs, nonpositive weights, missing behavior/asset reference, malformed union params, unsafe numeric limits.
- DialogueValidator: dead links, unreachable nodes, unknown choices/actions/conditions, secret visibility and disabled completion.
- Quest state/migrations: objective updates, idempotent complete, future schema rejection and repeated migration behavior.
- Linear leveling (D-21): proposed `Level=1+floor(totalXP/100)` at 0/99/100/199/200 XP, multi-level grants, migration reconciliation, invalid/negative/nonfinite XP, and accumulated fractional progress under the finalized quantization rule. Ordinary proposed base XP equals 0.2×HP for all seven droids; boss base XP is a separate 100 override, not 0.2×5000. Assert effective pacing examples in [catalog](CONTENT-CATALOG.md), including map/scenario multipliers, killer ratio, per-contributor boss shares and XP boosts; do not add survival XP. Playtest evidence must measure kills/round, actual XP/hour and boss-win/contributor distributions before tuning acceptance.
- Free-spin connected clock (D-13): persisted remaining900; 300 seconds connected leaves600, 24 hours offline still600, 200 seconds after rejoin leaves400. Lobby/AFK both count; offline/restart gaps do not. Test exact zero, untrusted client clock, profile-not-ready handling, concurrent free claims, persisted cooldown reset900 only after the finalized atomic grant, paid/free independence, and leave/shutdown checkpoint ordering. A persisted Unix eligibility timestamp is not the approved clock model.
- Deferred/excluded scope: profile and private replica schemas omit Gems, HUD/wheel grant paths omit gems, chair/sofa/obby have no agent-owned content, price handlers or reward tests. Migration preserves unrelated existing user data safely if deferred fields are discovered; no live-profile experimentation.

## Transaction and receipt failure matrix

For each purchase/utility/wheel/token/donation flow, test normal success, insufficient funds/counts, cap, wrong state, simultaneous requests, state change while persistence yields, timeout/failure before durable commit, after commit before response, disconnect, shutdown and retry. Replica publication must reflect committed authoritative state; effects cannot grant free utility uses after failed persistence.

Receipt-specific: unloaded/failed profile, unknown/zero ProductId, repeated PurchaseId, concurrent same/different receipts, handler exception, durable save failure, delayed retry after rejoin/restart, history compaction/replay, pending paid spin/token consumption and crash recovery. A UI purchase-completed callback alone never grants a dev product. Use mocks first; live purchase testing is separately authorized and isolated.

## Multi-client abuse and lifecycle matrix

Run Server & Clients with at least two clients and inspect server plus every client Output. Include malformed types/tables/IDs; NaN/infinite aim values; huge payloads/strings; remote spam; fake prices/damage/wheel result; forged ownership/instances; out-of-range/no-LOS melee; fire-rate/ammo/reload abuse; invalid placement; old RoundId/entity generation; requests after death, leave, rapid respawn; purchase/equip outside Lobby; Gear in Backpack/Character in Lobby; admin requests from nonallowlisted users/production mode.

Verify private player replica data reaches only its owner; public match facts agree for both; no receipts/session internals leak. Missing streamed target/NPC/map cosmetic assets must not block indefinitely. Rejoin does not restore a round loadout or award survival twice. Spectate handles target dying/leaving and exits at end. Supported R6/R15 rigs and actual Animator/markers are checked explicitly.

## AI and destruction stress

All map/scenario cap fixtures, including Town It's Over 135 before event modifiers. Include worst configured event cap, allied cap, turrets, 2 bosses, close/remote targets and empty target sets. Check no per-droid Heartbeat, actor pool counts/batches, stale snapshot rejection, worker exceptions, path queue/backoff, blocked movement/unstick, recovery height versus engine kill height, 10 s independent respawns excluding last spawn, pool reset, server ownership and faction filters.

Only Tornado is production event content (D-16); no named alternative event/disaster stubs are required. Under the proposed repetition policy, test Regular0–1, NotRegular1–2, Weird2–3 and It'sOver2–3 independent Tornado instances, distinct scopes/IDs, Wind-only eligibility, and aggregate droid/effect/debris budgets. Stop/abort one instance without stopping siblings; teardown clears all instances and pending spawns idempotently. Finalize category-slot eligibility and repetition before accepting these integration fixtures.

Boss fixtures reuse the Regular brain, melee5/cadence1s, HP5000, proposed uniform size2 and no extra phases/abilities/player-count HP scaling. Test size-aware path clearance/hit checks, equivalent combat cadence, separate entity lifecycles, two-boss victory requiring both dead, and a boss still alive at the 240-second deadline triggering the losing outcome. Base XP100 override must remain independent of HP and scale. Never treat the proposed size as explicit owner approval of exact dimensions.

Mass explosions must spread across frames; destructibles alone break; debris collision/lifetime/cap hold; map re-clone restores baseline. Destroy or abort mid-event/ability/path request and confirm no delayed mutation survives its scope.

## Performance and soak gates

WS-J-03 defines numerical fields in Config/Perf after measurement: server frame average/p95, AI ms/frame, Actor utilization, path query budget, replicated traffic, pooled resources and effect/debris caps. Log device/hardware, build/contract versions, actual cap/scenario, duration and sampling method. 60 FPS target applies to representative low-end mobile; emulator/desktop results are labeled honestly.

Warm pools/workers before recording baseline. Run at least 20 consecutive rounds spanning normal timer, all-dead, early boss and boss-timeout outcomes, all maps/scenarios, joins/leaves/respawns, event/utility use and failure recovery. After each teardown and bounded drain, assert round-owned instances/connections/tasks/assignments=0 and persistent pools/Actors return to warmed baseline. Track scoped tasks/threads through the resource owner; do not claim an unavailable global counter exists. Keep intentional persistent lobby/player resources separate.

No steady upward leak trend; no watchdog stuck state; no residual tools/locks/replicas/cooldowns; no frame-time cap violation. Preserve sanitized logs and metrics as evidence in docs (not private profile snapshots).

## Data-only extension proof

In fixtures, add one gear, droid, map, class and event using an already registered strategy plus primitive asset if needed. Registry discovers them; validation, UI generation and round behavior work with no core changes. The event extension is a test-only Tornado-strategy fixture, not a shipped named non-Tornado stub. Demonstrate each recipe; then remove temporary fixtures from production registries. A new strategy is a separately reviewed change and cannot be called a data-only proof.

For the droid proof, exercise the reviewed R-20 opt-in rule: one new definition plus rig must actually spawn in an existing eligible map without editing that map's data. Test unknown MapId, duplicates, event-only opt-in rejection and preservation of all original map pools.

## Evidence template

```markdown
Task / milestone / contract version:
Files and Instances changed:
Commands, environment, exit codes:
Studio mode and client count; each Output result:
Devices/rigs, scenarios and cases executed:
Expected versus observed behavior:
Metrics/baseline and artifacts:
Failures/fixes; rerun evidence:
Checks not run and reason:
Relevant ADR/approval records:
```

Release is blocked by missing mandatory evidence even if mocks pass. Stop Studio sessions and clean temporary debug objects/harnesses after verification.
