# PlayThisGame

Project planning: [documentation index](docs/README.md), [implementation backlog](docs/PTG-TODO-List.md), and [agent rules](AGENTS.md). Coding is authorized; foundation contracts remain unfrozen. The owner authorized task agents to continue Match implementation before formal M1 completion.

## Match preview

From `D:\PlayThisGame`, run `rojo serve match.project.json` and connect the Studio Rojo plugin to that project. The isolated Studio preview wires sticky physical voting, three primitive map templates, AFK eligibility, character generation tracking, staggered teleport, round timers, results calculation, lobby return, and a bare HUD. The original default project mapping is preserved; the foundation project also has an opt-in preview selector.

An existing connection to `foundation.project.json` also supports the preview: in Studio Edit mode, set `ReplicatedStorage.MatchPreviewMode.Value` to `true`, then Play. This selector defaults to `false` in the source project, so reconnecting restores foundation mode. Both foundation fixtures skip themselves in preview mode. The preview HUD clones its authored `ReplicatedStorage.MatchPreviewTemplate`; owner-authored `StarterGui` content remains intact. `match.project.json` selects preview mode by default and maps its disabled HUD template into `StarterGui`; the controller enables it after binding.

Workstream C has source implementations for WS-C-01 through WS-C-07, including damage/stat/status services, loadout, ammo/cooldown request guards, projectile adapter, melee/booster strategies, and the typed nine-gear catalog with primitive Tool assets. Combat integration is running with an explicitly injected memory-only Studio smoke; the composed one-client check passed. FastCastRedux is not installed, so the adapter is not verified against real FastCast. Lightsaber `summon_ally` still awaits F's summon callback. Missing attack/reload/range/knockback/jump tuning remains `TODO(owner)`; the proposed speed policy is not approved final tuning. The Studio Match preview now selects real droids and C damage/stat/status services; player gear/loadout, persistence and events remain staged. WS-C-08 remains open pending actual multi-client evidence. The HUD reads public preview attributes. The connected-Studio continuation fixes native stub-return checks, vote-close publishing, monotonic round IDs across loop restarts, and bounded nonzero Studio test-player IDs. Pure Match regression cases are prepared in `tests/unit/match/Run.luau`; unit suites remain unrerun at the owner's request. No evidence files were added or updated.

Workstream D source is implemented through WS-D-07: seven frozen definitions and primitive rigs; cap-aware pooled spawning; independent ten-second respawns; pure behavior trees; immutable Actor snapshots; bounded worker retries, LOD and serial movement/attack actuation. `DroidRuntime` owns one optional Heartbeat. Paths have bounded queues/concurrency and explicit cancellation cleanup. `DroidPreview` connects the existing Match facades to real D and C damage/status without starting persistence, player Tools or events. `MapService.GetContext` exposes the frozen loaded map context. Eligible definitions opt into map pools through their `Maps` field, so an existing behavior needs only a definition and asset.

Prior one-client Studio probes passed caps50/50/75 across the three map definitions, independent respawn/generation/pool reset, void recovery, server ownership, allied owner/lifetime cleanup, all seven melee definitions, injected projectile handoff, Lunge/shock/status overlap and wall guards. Real Actors returned decisions; a separate failure probe passed53 assertions covering brain failure isolation, bounded worker recovery, stale generations, receipt expiry and teardown. A live Match preview reached Active with75 droids. The final live damage/round-cleanup observation was interrupted when the owner requested fewer Play tests; it is not claimed as passed. No further Play session or unit-suite rerun is required for routine continuation; use static checks and reserve Studio checks for necessary engine tasks.

WS-D-08 acceptance remains open for complete live integration, representative cap/performance measurements, multiplayer and device evidence. Missing Range/Worker projectile transport and unspecified Chaser/Wind/Police tuning fail closed until injected; test-fixture tuning is not approved balance. FastCastRedux remains absent. No Workstream E work was started. Owner explicitly authorized the C/D source checkpoint commit/push on 2026-10-09 and continuation into E; formal acceptance gates remain open.

D size exceptions: DroidService coordinates slot generations, synchronous callback guards, cancellation, pool leases and independent deadlines in one lifecycle facade; Actuator keeps fresh admission/contact checks and owned movement modifiers together; DroidRuntime keeps serial sensing, scheduling and teardown ordering together. Pure policies, trees, scoring, snapshots, paths and configuration are separate modules.

GearService reads `Shared.Config.Gears` as a frozen catalog (`Definitions` and `ById`); each definition's `AssetId` matches its stable ID and the Tool model imported under `ServerStorage.Assets.Gear`. The catalog discovers definition modules, so an additional gear follows the existing strategy by adding a typed definition and matching primitive asset.

`CombatRuntime.new` composes C behind injected data, selection persistence, active-round state, clock, timers, tuning and optional projectile/ability ports. `LoadoutDataAdapter` persists the selection through B's transaction engine and Lobby reservation. The caller begins the damage round, grants frozen loadouts, reads result facts, then clears the round. Empty loadouts still register damageable players; death/removal cancels that generation's status timers and removes its modifiers, rig bindings and world reference. Maximum-HP modifiers preserve current HP and clamp on reduction; toggling them does not heal.

Networking is explicit: create or reuse the canonical `Shared.Remotes` Folder, then call `runtime.bindRemotes(folder)` once. It binds `UseGear`, `ReloadGear` and `UseAbility`, with targeted `CommandResult` acknowledgements. Runtime destruction releases its owned endpoints/connections and preserves the shared acknowledgement endpoint. A separate one-client Studio check passed real RemoteEvent dispatch, server-supplied identity, duplicate/collision rejection, replay/shape/rate guards and binding cleanup. This check used injected state/handlers and does not establish real combat replication between two clients. Prepared gateway regressions are registered without executing the unit suite.

Combat facade size exceptions: `CombatRuntime` keeps composition and teardown order together; `GearService/Implementation` keeps private Tool, ammo and cooldown admission in one boundary. Pure calculations, projectile transport, geometry, loadout persistence and character ownership are separate modules. Neither exception expands C's ownership.

The A-to-B continuation added scheduler-bound outcome arbitration, per-player AFK/character rechecks during teleport, explicit map vote weights, validated pick overrides, and interface-based loadout/droid/event/boss/projectile orchestration. Results now return players and unload the map immediately, use available authoritative round statistics for MVP, and withhold settlement if required facts are unavailable. The preview deliberately skips unavailable services and never pays rewards. A fresh Studio check confirmed that the first of two boss reports preserves Active, the second starts celebration, and Results returns the survivor to Lobby with the map unloaded. A source implementation exists for A-01 through A-08; A-08 acceptance remains open until real B/C/D/E/G services and full multiplayer/catalog checks exist.

Workstream B now has source implementations for its profile adapter/schema/migrations, private/public ReplicaService wrapper, reward settlement, serialized transactions/boosts, shop/inventory and bounded recovery/autosave. The WS-B-03/05/06 agents integrated those changes through injected boundaries. Purchases reserve the player's Lobby eligibility across queue/save yields, then persist the charge and grant together. Unique items, utility cap100, wheel/admin acquisition and state guards are enforced server-side. Boost expiry is persisted; duration/multiplier policy remains injected. Reward contexts retain authoritative contribution/tuning snapshots, and per-recipient journal entries make partial retries skip confirmed payouts. A caller must retain/retry incomplete settlements; automatic/durable offline delivery is not implemented.

Studio checks with injected memory storage and replica transport passed atomic purchases, retry/unique/cap guards, round-entry exclusion during saves, boost retry/expiry, private audiences, projection rejection, candidate ownership and failed-purchase recovery. A separate reward/recovery check passed the ordinary 0.59 killer ratio, Big Boss 175 XP fixture pool, partial-survival retry, three-attempt load recovery, failed-load readiness and release confirmation retries. A concurrent Release/Stop check confirmed shutdown waits for the disconnect cooldown checkpoint before destroying the adapter. These checks do not require ProfileService or exercise DataStores/real ReplicaService networking. Default boot still uses safe Data stubs. Real rejoin/server-close sessions, multiplayer private delivery, upstream context integration and journal compaction remain open. The journal currently fails closed at 256 entries rather than discarding idempotency records. Prepared regressions were registered but not executed under the owner's no-suite-rerun exception.

Review size exceptions: GameLoopService/Implementation (406 lines) retains scheduler and arbitration; MatchSession (323 lines) retains transition ordering; ProfileAdapter (336 lines including types) shares key ownership across load/save/confirmed release. DataService/Implementation (388 lines) coordinates the same records/generations across commits, recovery, autosave and shutdown; PlayerStateService/Implementation (414 lines) coordinates character generations, round state and Lobby leases. Pure transactions, schemas, recovery, scheduling and cross-domain effects are extracted. Their integrated ownership ordering warrants the remaining facade size; these exceptions do not expand workstream ownership.

Connected-Studio checks on 2026-10-08: one natural 240-second non-boss round reached `Survived`/Results, returned the player to Lobby, and removed its map clone. Physical pad votes switched and remained sticky off-pad; entering the AFK zone returned the solo server to Idle; loop Stop/Start retained increasing round IDs. Death/respawn returned a replacement character to Lobby with a newer generation and a single persistent HUD. All three map templates loaded/unloaded through the actual MapService, and seeded ScenarioDirector calls produced all five plan types. Unknown maps, absent voters, stale boss reports and stale character teleports were rejected. Temporary probes were removed by stopping Play, and Edit hierarchy cleanup was confirmed. These one-client preview checks do not verify enemy/event execution, two-client networking or a 20-round soak. Authored Luau format/lint, pure and Roblox strict analysis, and both Rojo builds passed; the headless test suites were not executed in this continuation.

Generated by [Rojo](https://github.com/rojo-rbx/rojo) 7.7.1.

## Getting Started
To build the place from scratch, use:

```bash
rojo build -o "PlayThisGame.rbxlx"
```

Next, open `PlayThisGame.rbxlx` in Roblox Studio and start the Rojo server:

```bash
rojo serve
```

For more help, check out [the Rojo documentation](https://rojo.space/docs).

## Foundation development

The Studio-only server bootstrap registers 29 typed safe stubs behind the Knit adapter. Stub commands return `NotReady`; they never grant coins, load profiles or acknowledge receipts. Contracts remain v0/unfrozen. The top-level `Configs/` and `Controllers/` directories disappeared externally during this continuation. Their foundation/local default Rojo nodes preserve unknown Studio descendants without referencing absent disk paths; existing Studio weather content remains present, while fresh foundation builds contain empty containers. Foundation also preserves the owner's existing Services descendants without mapping unrelated weather source. `Services/WeatherService.luau`, default-project changes and the user's Wally namespace changes remain local outside the A/B checkpoint commit.

Run from `D:\PlayThisGame` in PowerShell:

```powershell
# Install the approved local Windows development tools and definitions.
./tools/toolchain/install-windows.ps1

# Read-only formatting check, pure suites, 29 shell checks, lint, types and build.
./tools/check-foundation.ps1

# If an Aftman shim cannot find its home directory, pass the installed pinned Rojo executable.
./tools/check-foundation.ps1 -RojoPath 'C:/Users/mnmyu/.aftman/tool-storage/rojo-rbx/rojo/7.7.1/rojo.exe'

# Current owner exception: static checks and build, without rerunning unit suites.
./tools/check-foundation.ps1 -SkipTests -RojoPath 'C:/Users/mnmyu/.aftman/tool-storage/rojo-rbx/rojo/7.7.1/rojo.exe'

# Run the pure/bootstrap tests separately.
./tools/toolchain/bin/lune.exe run tools/test-unit.luau

# Build or serve the isolated Studio harness project.
rojo build foundation.project.json -o tools/toolchain/bin/foundation.rbxlx
rojo serve foundation.project.json
```

Approved development pins: StyLua2.5.2, Selene0.31.0, Luau LSP1.70.1 and Lune0.10.5. `tools/toolchain/aftman.toml` records them; the local archive installer avoids a locked global Aftman alias encountered in this environment. Tools, generated type definitions, sourcemap and test place are ignored under `tools/toolchain/bin/`. The root Aftman pins remain Rojo7.7.1/Wally0.3.2; broader runtime package auditing is unfinished.

`tools/setup-require-paths.ps1` creates ignored junctions that mirror the authored Shared/Server hierarchy for headless `@game` imports; installation and foundation checks invoke it. Run it once before invoking Lune directly on a fresh checkout. Roblox resolves these imports through its real DataModel. No source modules are copied or generated packages edited.

Open the built foundation place in Studio and use Play, then Server & Clients with two clients. The server harness checks actual adapter-resolved stubs, three valid temporary map fixtures, two negative asset cases and 20 simulated stub cycles. `ServerScriptService.Server.FoundationHarnessStatus` must read `Passed`; failures expose `FoundationHarnessFailure`. Each client's `PlayerScripts.FoundationClient.FoundationBindingStatus` must read `Bound`, with a received revision/state/round. The snapshot is a Studio-only JSON Attribute fixture; rapid simulated transitions may coalesce into the final Idle snapshot. A bound client proves one validated observation, not observation of every cycle.

Capture server and each client Output and cleanup observations using the [evidence procedure](docs/evidence/PHASE-0-START.md). MCP access to the owner's place `91053595510509` is confirmed. Studio `0.742.0.7421053`, Play with one client: the repaired foundation harness reported `Passed` and the client reported `Bound`, revision 163, round 21, Idle. This is the simulated foundation fixture, not 20 live gameplay rounds. Two-client replication, private ReplicaService delivery, live persistence/payments, combat, live-round leaks and device performance remain unverified. Contracts remain unfrozen.
