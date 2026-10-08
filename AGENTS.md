# Play This Game — repository and agent instructions

## Project and source of truth

Build a Roblox round-based co-op survival v0.1: Lobby → Voting → Map → Round → Results → Lobby. The foundation must support new content through typed data definitions and assets, using reusable behavior strategies. Use primitive Parts and bare functional Frames. The owner supplies final models, design, art, audio and dialogue.

Planning source: `D:\13Games\PLAY_THIS_GAME_BRIEF.md` (v0.1). See [documentation index](docs/README.md), [glossary](docs/GLOSSARY.md), [backlog](docs/PTG-TODO-List.md), and [decisions](docs/DECISIONS.md).

**Current authorization:** owner authorized writing code for each group on 2026-10-08, then approved the remaining implementation actions and asked for no repeated confirmation. The owner's latest exception authorizes continuing gameplay phases with task-specific subagents before formal M1 completion, fixing draft contracts directly, skipping test reruns, and omitting new evidence-file entries. Contracts remain unfrozen; this authorization does not establish Studio evidence. Preserve existing dependency approvals and file reservations. See [thread map](docs/TASK-THREADS.md) and the historical [implementation evidence](docs/evidence/PHASE-0-START.md).

## Current repository versus target

This repository is not empty. It contains `src/{shared,server,client}`, top-level `Configs/Weather`, `Services/WeatherService.luau`, `Controllers/WeatherController.luau`, `Packages`, `ServerPackages`, and a Rojo project. Boot scripts print greetings; this is not a wired game loop. Weather examples exist but their runtime behavior has not been verified.

Observed pins: Rojo `7.7.1`, Wally `0.3.2`, Knit `1.7.0`, ProfileService `1.1.0`. Availability and maintenance of each dependency must be verified before Phase 0 adoption. Aftman is already selected; retaining it avoids an unnecessary manager migration. ProfileService is acceptable under the brief; do not silently replace it with ProfileStore.

Existing user changes include `.gitignore`, `default.project.json`, `wally.toml`, and the weather directories. Preserve them. `.gitignore` currently excludes both `wally.toml` and `wally.lock`; Phase 0 must plan and validate tracking reproducible manifests/locks. Never edit generated package contents or `sourcemap.json` as source.

Target layout (not yet implemented):

```text
src/shared/   Types/ Contracts/ Framework/ Registry/ Util/ Config/<Domain>/
src/server/   Boot/ Services/{Match,Data,Combat,Droids,Events,Items,Lobby,NPC,Debug}/
              Systems/ Behaviors/{Gear,Utility,Armour,Class}/ AI/ Infrastructure/
src/client/   Boot/ Controllers/ UI/ Input/
assets/       Maps/ Droids/ Gear/ Utilities/ NPCs/ Lobby/
tests/        unit/<domain>/ integration/<domain>/ soak/ perf/ fixtures/
tools/        local validation, test runners, optional scaffolding
docs/         planning, architecture, ADRs, contracts, recipes, test evidence
```

The Phase 0 lead owns migration/mapping. Inspect Studio/Rojo ownership before moving existing content; map server templates into `ServerStorage`, shared modules into `ReplicatedStorage`, and persistent client boot into `StarterPlayerScripts`. Do not duplicate weather systems during migration.

## Commands and toolchain

Run from `D:\PlayThisGame`. Listed current commands are configured by existing files, **not claimed to have passed in this planning task**.

| Purpose | Command | Status |
|---|---|---|
| Install pinned tools | `aftman install` | Current manifest pins Rojo/Wally only; installation is a separate action |
| Install current packages | `wally install` | Current manifest; verify registry/lock before adopting |
| Build place | `rojo build default.project.json -o PlayThisGame.rbxlx` | Current project mapping |
| Serve to Studio | `rojo serve default.project.json` | Current project; connect the Studio Rojo plugin |
| Format | `stylua src tests tools` | Local tool/config added; executed local binary paths are in README |
| Check format | `stylua --check src tests tools` | Planned |
| Lint | `selene src tests tools` | Local Selene installed and verified; use README commands |
| Generate sourcemap | `rojo sourcemap default.project.json --output sourcemap.json` | Planned type-analysis prerequisite |
| Type-check | `luau-lsp analyze --sourcemap=sourcemap.json src tests tools` | Proposed; verify pinned CLI and Roblox definitions in WS-0-02/09 |
| Unit tests | `lune run tools/test-unit.luau` | Bootstrap runner implemented; use local Lune path in README; full domain suite pending |
| Mock integration tests | `lune run tools/test-integration.luau` | Planned; pure mocks only |
| Config validation | `lune run tools/validate-config.luau` | Planned; pure adapter needed for Roblox-specific values |
| Full local checks | `lune run tools/check.luau` | Planned orchestrator; must propagate exit codes |

Do not claim these planned commands work until Phase 0 adds and verifies them. No npm commands are configured. Studio integration, device tests, physics, Actors and live persistence cannot be replaced by headless mocks. Exact approved pins and working command syntax belong in root `README.md` during Phase 0.

Mandated architecture: Knit behind a thin `Framework` adapter; ReplicaService wrapper; ProfileStore or acceptable existing ProfileService adapter; FastCastRedux for projectile simulation; ZonePlus or approved in-house zone queries; Signal, cleanup utility, Promise, TableUtil and `t` validation. Select Jest-Lua or TestEZ with a Lune-compatible pure test path. Verify availability, maintenance, licenses and transitive packages in an ADR before adoption. Adding dependencies requires owner approval.

## Architecture and dependency rules

1. Phase 0 is serial: typed contracts, per-service Interface + Stub, registry/validators, lifecycle scopes and build checks before gameplay implementation. Freeze Contracts v1 only after its gate passes; [CONTRACTS.md](docs/CONTRACTS.md) is currently a proposal.
2. `shared` cannot require server or client modules. Server/client consume shared modules and interfaces. No cyclic requires, client access to server internals, or replicated secrets.
3. Resolve services through the adapter/injection; use typed signals for cross-system notifications and narrow interface calls for commands/queries. No direct implementation-module imports across workstreams.
4. Registry auto-discovers definitions, validates references/weights/IDs and freezes public definitions. New content using existing strategies requires only a definition and asset; new mechanics require a separately owned behavior task.
5. Compose behavior strategies, passives, abilities and BT subtrees. Use explicit state machines for round, player, droid and event state.
6. Separate pure logic from Roblox APIs. Inject RNG and clocks into formulas, transitions, ammo, cooldowns and tests.
7. Every connection, Instance, task and animation track has a scope owner. Use server/player/character/round/entity scopes; `RoundScope` tears down everything owned by a round.
8. Server owns HP, ammo, cooldowns, currency, inventory and results. Clients send intents. Validate shape, finite values, range, state, ownership, current character, proximity and rate limits before expensive work.
9. Private replicas target their player; shared match replicas contain public facts only. Never invoke clients synchronously from the server. Reuse canonical remotes rather than creating parallel protocols.
10. Droid physics are server-owned. Actor workers read snapshots and return decisions; serial actuation applies mutations. Use a bounded Actor pool, scheduler and AI LOD; no per-droid Heartbeat connections. Verify API thread safety before implementation.
11. Error boundaries isolate droid/event/ability failures. Watchdogs, bounded retries and shutdown paths are required.

## Coding and asset conventions

- `--!strict` in authored Luau, including tests and tooling where supported; type public APIs and Moonwave-style documentation comments.
- PascalCase modules/services/types; camelCase functions/locals; UPPER_SNAKE constants. Content IDs use stable snake_case matching the catalog. Use tabs for Luau indentation, enforced by planned StyLua config; two spaces for JSON.
- Prefer modules around 300 lines or fewer and functions around 50 lines or fewer. Record justified exceptions in review; split by responsibility, not arbitrary line counts.
- No globals, cyclic requires, deprecated `wait/spawn/delay`, or polling `while true` where events/schedulers suffice. Use `task.*` with cancellation and ownership.
- All gameplay values, rates, durations, limits and formulas live in typed config. Freeze constants/enums. Mark unspecified tuning `TODO(owner)` and link its decision.
- Bind existing and future characters; recheck character/generation after yielding. Tear down tracks/tools/connections on death/removal; handle R6/R15 through a documented adapter.
- Set Instance properties before parenting; use meaningful folders, tags and Attributes. Wait with timeouts where appropriate; tolerate optional streamed assets being absent.
- Store assets under `assets/` with the [draft asset contract](docs/MODEL_CONTRACT.md). Do not invent polished models, themed UI, sounds or dialogue.
- Input uses the brief's `ContextActionService` abstraction; replacing it needs an ADR/approval. Utilities have separate actions from three gear slots.

## Approval, decisions and contract changes

Ask first for model/UI design beyond placeholders, git commit/push, new dependencies, replacement of mandated libraries, frozen-contract changes, or changes to the brief's economy numbers. Do authorized reversible work without repeatedly requesting the same permission. Never interpret documentation approval as authorization to install or replace packages.

Use unchanged brief defaults without blocking the plan, but apply the owner's confirmed overrides first: round 240 seconds, boss deadline 240 seconds, non-boss killer rewards/boss contributor sharing, connected-time-only free spins, Tornado-only content, Regular-derived boss HP×50/larger rig, no chair/sofa/obby implementation, no active gems, linear leveling and a speed-stack nerf. Exact leveling/speed/scale and wheel-normalization proposals are not owner-confirmed constants. Preserve decision IDs (D-20/D-23 absent); do not repeatedly ask about confirmed choices.

ADR entries must include status, context, options, decision, config/contract impact, verification source/date, consequences, owner approval evidence and linked task. Planning assumptions remain provisional. An owner-approved exception takes precedence over these guidelines.

For a frozen-contract change, add a `CCR-nnn` entry to the backlog: affected symbols/version, motivation, old/new shape, consumers, compatibility/migration, tests, ADR and approval. The foundation lead updates the canonical contract after approval; workstreams do not cross-edit it. New valid content definitions are not themselves contract changes.

Owner authorization (2026-10-08): work on branch `ptg-initial`, and commit/push each workstream to that branch when its completion criteria are met. Do not request repeated commit/push permission for this workflow. Preserve accurate acceptance status; source implementation alone does not close integration gates. Never discard or commit unrelated user changes. Do not store credentials, private configuration or DataStore contents in the repository. If Git reports dubious ownership, use a scoped invocation when appropriate; do not change global Git settings as a convenience.

## Workstream role cards

Ownership below is the proposed post-Phase-0 layout. Each task lists its exact files. Shared schema/interface changes belong to the foundation lead; domain content is owned as listed. Each workstream owns its corresponding `tests/unit/<domain>` and `tests/integration/<domain>` tests; J owns shared harnesses, soak/perf/security suites. Respect active file reservations.

### Foundation lead (Phase 0)

Owns root configuration, boot/migration mapping, `src/shared/{Types,Contracts,Framework,Registry,Util}`, `src/server/Infrastructure`, initial service Interface/Stub shells, `tools`, and canonical contracts/docs. Produces registry, validation, lifecycle and Contracts v1. Forbidden: gameplay implementation before Phase 0 gate or unauthorized dependency changes. Done: stub loop, build, lint, type checks and headless checks pass, with Studio evidence for the stub loop.

### A — Match & Flow

Scope: loop FSM, scenario selection, sticky votes, maps, AFK, teleport, results/MVP and cleanup. Owns `src/server/Services/Match`, `src/shared/Config/{Maps,Scenarios}` and `assets/{Maps,Lobby/Match}`. Consumes PlayerData, Loadout, DamageFacts, EventLifecycle and cleanup contracts; produces MatchState, RoundContext, MapContext and AliveList. Forbidden: B persistence, C damage, E event internals, I UI. Done: every round outcome and join/leave/empty-server/watchdog case passes with deterministic tests.

### B — Data & Economy

Scope: profile sessions/migrations, replica publishing, coin rewards, shop/inventory, linear levels and boosts. Bosses distribute one contribution-based reward pool; ordinary droids retain killer-only rewards. Gems are deferred. Owns `src/server/Services/Data`, `src/shared/Util/Economy`, profile templates/migrations inside Data. Consumes DamageFacts/RoundOutcome and persistence adapter; produces PlayerData, EconomyTransactions and ReplicaPublisher. Forbidden: G receipt dispatcher, client UI, direct live-data experiments. Done: failure-safe load/save, session locking, transactions/rollback, target-specific rewards and rejoin/shutdown evidence.

### C — Combat Core

Scope: damage/stat/status pipelines, guns/melee, loadout snapshots, gear strategies, ammo/cooldowns. Owns `src/server/Services/Combat`, `src/server/Behaviors/Gear`, `src/shared/Util/Combat`, `src/shared/Config/Gears` and `assets/Gear`. Consumes RoundContext, PlayerData, Inventory and InputIntent; produces DamageFacts, StatModifiers, Projectile and Loadout contracts. Forbidden: I input bindings, F abilities/items, D AI scheduler. Done: authoritative combat, all nine gear definitions, lobby-tool and mid-round lock tests; F supplies summon behavior behind C's ability contract.

### D — Droid AI

Scope: spawning/pooling, BTs, Actor workers, perception/decisions, lifecycle/abilities and recovery. Owns `src/server/Services/Droids`, `src/server/AI`, `src/shared/Config/Droids`, `assets/Droids`. Consumes Damage/Status, MapContext and RoundScope; produces DroidLifecycle, BrainDecision and TargetSnapshot. Forbidden: C damage implementation, E boss/event policy, framework registry internals. Done: seven droid types, independent respawns, no per-droid Heartbeat, pool/LOD/budget and cap tests.

### E — Events, Bosses & Destruction

Scope: lifecycle, Tornado only, Regular-derived enlarged bosses and tag-based destruction. No other event stubs, new boss phases/abilities or player-count HP scaling. Owns `src/server/Services/Events`, `src/server/Systems/Destruction`, `src/shared/Config/{Events,Bosses}`, `assets/Droids/Bosses`. Consumes RoundContext, DroidLifecycle, Damage and scopes; produces EventLifecycle, BossOutcome, Explosion. Forbidden: A timers/outcome transitions, D base brains, final event art. Done: idempotent stop/cleanup, Tornado/Wind, HP 5000/larger-rig validation, two-boss tracking, 240-second deadline and debris budget tests.

### F — Utilities, Armour & Class

Scope: consumables, stat strategies, turret/ally/follower targeting and item-specific abilities. Owns `src/server/Services/Items`, `src/server/Behaviors/{Utility,Armour,Class}`, `src/shared/Config/{Utilities,Armours,Classes}`, `assets/Utilities`. Consumes InventoryTransactions, StatModifiers, Damage, Projectile, DroidLifecycle; produces UtilityUse and Ability strategies. Forbidden: C damage/stat core, B balance persistence, D brain core. Done: four utilities, three armours/classes, summon and consumption/cleanup/stacking tests.

### G — Lobby & Monetization

Scope: leaderboards, donations, wheel with connected-playtime free cooldown, receipts, gamepass queries and pick-token FIFO. Chair/sofa/obby logic/assets/purchases are excluded for the owner; gems and their wheel grant are deferred. Owns `src/server/Services/Lobby`, `src/shared/Config/{Products,Wheel}`, `assets/Lobby/Commerce`. Consumes B durable transactions, A selection window and Inventory; produces ReceiptGrant, WheelResult, PickQueue, BoardSnapshot. Forbidden: second ProcessReceipt owner, B session internals, active gem rewards, actual product creation/publishing. Done: durable receipts, offline-paused saved cooldown, reviewed non-gem wheel probabilities/prices, zero-ID guards, cached boards and concurrency tests.

### H — NPC & Quest

Scope: dialogue runtime/validator, four NPC graph stubs, minimal quest state. Owns `src/server/Services/NPC`, `src/shared/Config/Dialogue`, `src/shared/Util/Dialogue`, `assets/NPCs`. Consumes PlayerData, EconomyTransactions, DamageFacts and RoundOutcome; produces DialogueSession and QuestProgress. Forbidden: authored story/dialogue, arbitrary client callback execution, B schema cross-edits. Done: dead-link/unreachable validation, proximity/session guards, three quest objective kinds and four owner placeholders.

### I — Client & Placeholder UI

Scope: all listed controllers, HUD/hotbar, vote/shop/results/spectate/dialogue/boards, effects/device tiers and input. Owns `src/client/{Controllers,UI,Input}`, `src/shared/Config/Input.luau`, `src/shared/Strings.luau`, client fixtures. Consumes canonical intents, replicas and presentation signals; produces InputIntent and local cosmetic presentation. Forbidden: awarding damage/currency/results, server internals, themed UI/model design. Done: keyboard/touch/gamepad flows, respawn/streaming/private-state tests and unstyled inspectable UI.

### J — Quality & Tooling

Scope: common test fixtures/runners, security/perf/soak suites, debug commands, CI and recipes. Owns `tests/{fixtures,soak,perf,security}`, `src/server/Services/Debug`, test-only utilities, `src/shared/Config/Perf.luau` after foundation handoff, and assigned `tools`/docs/CI files. The debug UI subtree requires an explicit reservation/handoff from I. Consumes every published interface; produces evidence and failure reports. Forbidden: rewriting another stream's production module, bypassing approval, enabling production cheats. Done: all gates, 20-round leak assertion, cap/perf measurements and data-only extension proofs.

## Parallel coordination

The owner requested three grouped agent subthreads for planning/review: tasks 1–18 (foundation/match), 19–42 (data/combat/droids), 43–84 (content/client/quality), mapped in `docs/TASK-THREADS.md`. These are subthreads of this conversation, not independently created top-level chats. Phase 0 implementation remains single-agent/serial. When implementation is authorized, reserve files, consume Interface + Stub, and integrate M1–M5. A declaration dependency does not require the real service finished; a live demo does. C owns server validation; I client bindings. B publishes replicas; I reads them. D owns base droids; E owns derived boss definitions.

## Definition of Done and review checklist

- [ ] All 5 scenarios, 3 maps, 7 droids, 9 gears, 4 utilities, 3 armours, 3 classes, wheel, 4 boards, donations and 4 NPC stubs work as primitive placeholders.
- [ ] Full loop runs at least 20 consecutive rounds; round-scoped instances/connections/tasks/Actors return to the documented warmed baseline.
- [ ] Mid-round purchases/equip/loadout changes and gear use in the lobby are rejected server-side with adversarial tests.
- [ ] Receipts are durably idempotent; profiles survive rejoin and shutdown without saving defaults after failed loads.
- [ ] Droid caps are reached on all maps without violating measured/configured budgets; low-end mobile 60 FPS target is evaluated on documented hardware.
- [ ] New gear/droid/map/class/event using existing behavior is proven by definition + asset only, with no core edits.
- [ ] Format, lint, type-check, build, tests and config validation pass; Studio-only requirements have Studio evidence.
- [ ] No unrequested model/UI design or unapproved dependencies/contracts/economy changes; no unapproved commits/pushes.

For each change: identify task/contracts/files, explain resulting behavior, preserve unrelated edits, check security/cleanup/strict typing, add meaningful failure-path tests, document migrations/defaults, and report exact checks run/not run. PRs include linked tasks/ADRs, validation, material limitations and screenshots for visible changes. Suggest a focused Conventional Commit title; obtaining permission is required to execute it.
