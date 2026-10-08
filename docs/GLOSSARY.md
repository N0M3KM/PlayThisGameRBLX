# Project glossary

Use these terms in code, config, docs and UI strings. Avoid using zombie/monster/enemy as interchangeable domain names.

| Term | Meaning |
|---|---|
| Droid | Hostile AI entity; Allied Droid is the same framework with an allied faction |
| Round | One map play cycle |
| Scenario | Round type: Regular, Not Regular, Weird, Big Boss Droid, It's Over |
| Event | Round modifier with a scoped lifecycle; only Tornado is implemented in v0.1 |
| Event instance | One scoped occurrence of an event definition; proposed Tornado repeats have distinct IDs and share aggregate budgets |
| Disaster | High-severity Event category; v0.1 scenario slots use the Tornado-only policy in D-16 |
| Boss | Regular Droid reused at HP times 50 and larger size, with a 240-second deadline and contribution-shared rewards; no new phases/abilities |
| Gear / Utility / Armour / Class | Item categories; unique purchases except consumable Utilities |
| Loadout | Up to 3 gears, 1 armour, 1 class; utilities use separate actions |
| Loadout snapshot | Immutable server selection committed at teleport; used for round grants |
| Lobby | Persistent hub; gear use is forbidden |
| AFK Zone | Lobby region excluding a player from active round participation |
| Active Player | Non-AFK player eligible at teleport; eligibility also requires a loaded profile/current character |
| Contributor | Player with a positive damage ledger entry against a Droid |
| KillerOnly | Non-boss death reward policy; only the killer is paid using the source damage-ratio formula |
| Boss contribution sharing | Boss-event reward allocation across eligible contributors in proportion to credited damage |
| Linear level | Level derived from equal XP thresholds; proposed tuning is 100 XP per level, starting at level 1 |
| Connected-playtime | Time while the player is connected, including lobby/AFK; offline time never advances the persisted free spin countdown |
| Speed cap | Proposed maximum 32 studs/s after strongest-active-buff composition; tuning remains provisional |
| MVP | Separate leaders for kills, damage and assists in a round |
| RoundScope | Owner of all round-lifetime resources; destroyed at teardown |
| Contract | Typed interface, request/fact, signal or replica schema shared across ownership boundaries |
| Stub | Safe deterministic implementation of a contract for integration before real behavior exists |
| Pick Token | Durable entitlement to select map + scenario for a future eligible round |
| Definition / Registry | Typed domain data file / boot-time discovery, validation and freeze |
| Framework adapter | Thin boundary wrapping Knit so business modules avoid direct framework coupling |
| Decision / Actuation | Worker-computed AI intent / serial server application of that intent |

Canonical proposed round states: `Idle`, `Intermission`, `Voting`, `Loading` (MapAnnounce), `Teleport`, `PreRound`, `Active`, `Resolution`, `Results`. Canonical proposed player states: `Lobby`, `InRound`, `Dead`, `Spectating`; AFK is a separate flag. Exact serialized values become binding only at Contracts v1 freeze.
