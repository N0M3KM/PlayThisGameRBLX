# Play This Game — grouped task review threads

D implementation handoff (2026-10-09): `WS-D-01` / `ws_d_01_brains` owns BT/brains and hardened spawner/Actuator; `WS-D-04` / `ws_d_04_actors` owns Actor/snapshot/scheduler/path fixes and read-only reviews; `WS-D-06` / `ws_d_06_catalog` (GPT-6 Luna) owns definitions/primitive rigs/catalog validation and prepared spawn probe. Root owns runtime, C bridge, Match preview integration, canonical draft updates and documentation. All reservations released. D source is implemented; D-08 acceptance remains open. No E thread started. Owner requested fewer Play tests; Studio is stopped, temporary probes removed, and final checks are static-only. Owner explicitly authorized a C/D source checkpoint commit/push and E continuation on 2026-10-09; acceptance remains open.

## Current C continuation checkpoint (2026-10-08)

The A/B source checkpoint was committed and pushed as `a4da730ce13bf0bc10f521c133576fab80b3b29f`; A/B acceptance gates remain open. WS-C-01 through WS-C-07 now have source implementations and integration is running: damage/stat/status and rig adapters, loadout, ammo/cooldown/gateway, projectile adapter, melee/booster strategies, and all nine typed gear definitions with primitive Rojo Tools. Do not mark Workstream C complete from source presence.

The composed one-client Studio smoke passed with explicitly injected memory-only storage and projectile transport, including empty loadouts and death/respawn cleanup. No evidence-file entry was added under the owner exception. The main Match preview still runs against safe Combat stubs. FastCastRedux is not installed, F's Lightsaber summon callback remains pending, and owner weapon/jump tuning has not been approved. WS-C-08 is pending actual multi-client combat and abuse evidence. Contracts remain unfrozen and the unit-suite rerun exception remains active.

## Completed A-to-B continuation reservations (2026-10-08)

C task handoffs: `ws_c_01_damage` delivered damage/ledger, projectile/FastCast adapter, published draft lifecycle interfaces and canonical remote binding. `ws_c_02_stats` delivered stats/status/rig, loadout/private Tool grants and per-character cleanup. `ws_c_07_catalog` (GPT-6 Luna) delivered nine definitions/primitive Tools, prepared gateway regressions and checkpoint documentation. All C agent reservations are released. Root owns the integrated runtime, authoritative melee/boosters, ammo/cooldown/gateway, B selection adapter, A lifecycle hooks, static checks and Studio integration. WS-C-08 remains open.

Current B continuation completed its source handoffs; all task-agent reservations are released. `ws_b_05_transactions` delivered mutations/FIFO/boosts, reward context/settlement and yield-ownership fixes. `ws_b_06_shop` delivered inventory/catalog/shop/lease types, bounded load recovery/autosave and explicit-release shutdown tracking. `ws_b_03_replicas` delivered the injected ReplicaService adapter/projection/lifecycle wrapper. Each prepared regression fixtures and passed focused static checks without running unit suites. Root integrated draft contracts, real A Lobby reservations, memory Studio checks, docs and Git workflow. Owner authorized commit/push to `ptg-initial` upon workstream completion, then explicitly requested the A/B checkpoint push recorded above. Acceptance gates remain open; this is a source checkpoint.

Owner requested completion of A followed by B, with task-specific subthreads and Studio access. No new approval is needed for this authorized implementation. Completed thread handoffs (all reservations below released):

- `ws_a_01`: A-01/06/07 arbitration/recovery in GameLoopService and shared RoundMachine; integrated, reservation released.
- `ws_a_04`: A-02/03/04/05 player/teleport/vote/map/scenario lifecycle fixes; integrated, reservation released.
- `ws_a_08`: MatchSession, RoundIntegration and server ResultsCalculator orchestration; integrated, reservation released.
- `ws_a_03` (GPT-6 Luna): read-only three-map definition/asset audit; completed with no discrepancies.
- `ws_b_01`: ProfileAdapter and injectable ProfileService runtime wrapper; integrated. `ws_b_01_imports` integrated Studio/headless imports and confirmation tracking for sessions and discarded raw loads.
- `ws_b_02`: profile types/template/migrations and Data config; integrated, reservation released.
- `ws_b_04`: pure reward and XP math plus prepared regressions; integrated, reservation released.
- `ws_b_05`: DataService session/transaction/autosave/shutdown core; integrated, reservation released. `ws_b_05_review` supplied a read-only durability review.
- Root: shared draft contracts/stubs/catalog, boot/presentation, injected memory fixture, Studio checks, tooling/test registration and documentation integration.

Agents must report missing real-service dependencies honestly. WS-A-08's complete live acceptance still requires B/C/D/E/G integrations; implementing A's hooks does not complete that gate. Prior no-unit-suite-rerun/no-new-evidence-file exception remains in effect.

Created 2026-10-07 at the owner's explicit request to open a thread for each task group. These are agent subthreads within the current conversation, not newly created top-level user chats. The owner authorized coding on 2026-10-08 and approved remaining actions. The latest owner exception authorizes additional task-specific implementation agents before formal M1 completion; root integrates their reserved changes.

The [backlog](PTG-TODO-List.md) retains all 84 task IDs, metadata and dependency edges. Ordinals below follow workstream order `WS-0`, then `WS-A` through `WS-J`, with numeric task order inside each stream. They do not follow the backlog's displayed phase-section order, because integration tasks appear later there. Task IDs remain the canonical references.

Latest owner exception (2026-10-08): gameplay implementation may proceed with separate task agents before formal M1 completion; no unit-suite reruns or new evidence-file entries this pass. Match task agents implemented player state, teleport, scenarios, results, primitive lobby, HUD, and map validation; grouped agents supplied the pure loop/vote cores and content catalogs. Root integrated boot, scheduling, cancellation, draft interfaces/stubs, and `match.project.json`. These reservations are released. MCP access now reaches the owner's Studio workspace. Root repaired the foundation harness and continued live Match validation; `match_runtime_review` reviewed Match and supplied 12 prepared pure regression cases, which root formatted/type-checked and wired into the existing runner without executing. The connected foundation project now supports an opt-in Match preview while preserving owner-authored UI. Combat/droid/event/data integration and broader multiplayer/device validation remain pending; contracts are not frozen.

| Group / agent subthread | Ordinal task range | Canonical IDs | Planning focus |
|---|---|---|---|
| Group 01 — `group_01_foundation_match` | 1–18 | WS-0-01…10; WS-A-01…08 | Serial foundation gate, contracts, match timers, scenario counts, resolution and cleanup; propagate owner choices through the complete backlog |
| Group 02 — `group_02_data_combat_droids` | 19–42 | WS-B-01…08; WS-C-01…08; WS-D-01…08 | Persistence and reward policy, online-only free-spin state, linear XP pacing, speed composition and Regular-derived boss compatibility |
| Group 03 — `group_03_content_client_quality` | 43–84 | WS-E-01…07; WS-F-01…08; WS-G-01…08; WS-H-01…04; WS-I-01…06; WS-J-01…09 | Tornado-only content, enlarged baseline boss, item/UI/lobby scope reductions, recipe/test plans and release evidence |

These named agent subthreads were created in the current conversation and completed their initial documentation reviews. They remain available for follow-up tasks. The root conversation integrates their findings and owns canonical decision/contract changes. The ordinal ranges remain stable even if display labels change.

| Ordinals | Workstream | Exact task range | Count |
|---|---|---|---|
| 1–10 | Foundation | WS-0-01…WS-0-10 | 10 |
| 11–18 | A — Match & Flow | WS-A-01…WS-A-08 | 8 |
| 19–26 | B — Data & Economy | WS-B-01…WS-B-08 | 8 |
| 27–34 | C — Combat Core | WS-C-01…WS-C-08 | 8 |
| 35–42 | D — Droid AI | WS-D-01…WS-D-08 | 8 |
| 43–49 | E — Events, Bosses & Destruction | WS-E-01…WS-E-07 | 7 |
| 50–57 | F — Utilities, Armour & Class | WS-F-01…WS-F-08 | 8 |
| 58–65 | G — Lobby & Monetization | WS-G-01…WS-G-08 | 8 |
| 66–69 | H — NPC & Quest | WS-H-01…WS-H-04 | 4 |
| 70–75 | I — Client & Placeholder UI | WS-I-01…WS-I-06 | 6 |
| 76–84 | J — Quality, Tooling & Release Gates | WS-J-01…WS-J-09 | 9 |

Review all tasks within each range, including their later integration entries. Report findings to the root without editing another group's reserved files or canonical shared contracts. Cross-group dependencies are satisfied by reviewed interfaces/stubs during planning; live milestone evidence still requires real services and the preceding gates.

| Agent thread | Documentation reservations |
|---|---|
| `/root/group_01_foundation_match` | `docs/PTG-TODO-List.md`, `docs/TASK-THREADS.md` |
| `/root/group_02_data_combat_droids` | `docs/CONTENT-CATALOG.md`, `docs/TEST-PLAN.md` |
| `/root/group_03_content_client_quality` | `docs/ARCHITECTURE.md`, `docs/MODEL_CONTRACT.md`, `docs/GLOSSARY.md`, `docs/recipes/**` |
| `/root` | `AGENTS.md`, `docs/DECISIONS.md`, `docs/CONTRACTS.md`, `docs/README.md`, final consistency validation |

These historical documentation reservations have been handed back to root. All implementation checkboxes remain unchecked; foundation artifacts are In progress, and gameplay is queued behind M1. The root integration review may update canonical documents after each group's handoff; that does not start gameplay work.

The accepted owner choices are recorded in [DECISIONS.md](DECISIONS.md). Round and boss deadline are both 240 seconds. Non-boss rewards use KillerOnly; boss rewards share one contribution pool. Persist remaining free-spin time and count down only while connected, including lobby/AFK. Implement only Tornado and a Regular Droid boss with HP ×50 and larger size. Exclude chair/sofa/obby and Gems. Use linear leveling and nerf speed stacking.

The group review distinguishes these choices from proposed tuning: repeat scoped Tornado instances to retain scenario counts; boss uniform scale 2; 100 XP per level, ordinary XP of 0.2 × base HP and a separate boss XP pool of 100; strongest active speed factor with a 32 studs/s cap from a baseline of 16; seven wheel weights totaling 92 after reserving the disabled Gem entry. These proposals require the documented simulations/playtests and, for final wheel probabilities, owner approval. No additional confirmation is requested during this documentation task.

When implementation is separately authorized, WS-0-01…10 remain a single-agent serial sequence. Pass WS-0-10/M1 before gameplay implementation. Then reserve actual production/test files by workstream and integrate M2 → M3 → M4 → M5. These review groups are useful handoff packets, not a replacement for dependency ordering or file ownership in [AGENTS.md](../AGENTS.md).

## Coding handoff checkpoint - 2026-10-08

Root reserved `src/shared/{Contracts,Config,Framework,Registry,Util}`, `src/server/{Boot,Infrastructure,Services/**/{Interface,Stub}.luau}`, boot scripts, the foundation MapValidator/fixture, local tooling/tests and canonical docs. Every group's service contracts and safe stubs now compile. Agents reviewed without editing production code; root remains the sole Phase 0 implementer.

Groups01/03 reported source fixes; Group02 supplied initial contract recommendations. Root integrated: detachable scopes, isolated loop callbacks, startup dependency resolution, actual Knit facade registration, canonical boss StopRound naming, typed player transitions with round/generation, and combined map/scenario pick entitlements. Gameplay files are reserved only after WS-0-10/M1 passes. [Evidence](evidence/PHASE-0-START.md) distinguishes executed local checks from prepared Studio checks.

Group02 dependency-audit checkpoint: no new package identity, pin, license, maintenance or transitive verification was established. ReplicaService, FastCastRedux, ZonePlus, Trove, TableUtil, t and TestEZ remain pending; no package adoption was inferred from planning observations.

## Connected-Studio continuation - 2026-10-08

Owner authorized continued coding and subagents after connecting Studio. The three same-named grouped review subthreads ran read-only; root retained serial Phase 0 source/tool/doc ownership. Reviews identified request/schema gaps, missing atomic/durable inventory grants and reward context, unversioned Actor snapshots, incomplete content discovery/signals/adapters, asset and harness defects, and the absence of callable Studio tools in this turn.

Root integrated 13 canonical request schemas, correlated acknowledgements, specific GearService request signatures, minimal snapshot validators and injectable client bindings. Added metatable/partial-freeze rejection, recovery anchoring/malformed-spawn checks, exact fixture naming, scoped loop cleanup and explicit harness status. The prepared Studio-only public Attribute transport/client fixture does not replace ReplicaService or prove live multiplayer/private replication. Local checks now pass 50 pure tests and 29 static shell checks; M1 remains open. [Evidence](evidence/PHASE-0-START.md) records exact commands and remaining gates.
