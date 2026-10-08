# v0.1 content and balance catalog

Planning catalog, not implemented config. Owner clarifications D-01/02/05/13/16/17/18/21/26 supersede the corresponding source defaults; see [DECISIONS.md](DECISIONS.md). Other source numbers remain unchanged. Linear XP balancing, the speed cap, boss size and Tornado repetition below are explicitly proposed tuning or engineering choices rather than owner-approved constants. Display names come from the source; snake_case IDs for maps/NPCs/products are proposed where the source provided only names.

## Scenarios (5)

| Id | Name | Roll weight | Droid multiplier | Events | Disasters | Bosses | Reward multiplier |
|---|---|---:|---:|---|---|---:|---:|
| regular | Regular | 50 | 1.0 | 0–1 | 0 | 0 | 1.0 |
| not_regular | Not Regular | 35 | 1.2 | 1–2 | 0 | 0 | 1.2 |
| weird | Weird | 10 | 1.2 | 2–3 | 0 | 0 | 1.5 |
| big_boss | Big Boss Droid | 4 | 1.5 | 0 | 0 | 1 | 1.75 |
| its_over | It's Over | 1 | 1.8 | 0 | 2–3 | 2 | 3.0 |

Scenario weights total 100. Rates are identical across maps. Seeded RNG is injectable. Active rounds last **240 seconds** (D-01); boss rounds have a **240-second deadline** from Active entry (D-02). Both bosses in It's Over must die; an early defeat still stops the timer and enters the existing 10-second celebration.

**Only Tornado is implemented** (D-16). There are no other named event/disaster stubs. To preserve the source counts, the proposed selection policy creates independent Tornado instances, with separate IDs/scopes, for each required Event or Disaster slot. Category eligibility/repetition must be finalized in the contracts before implementation; it must not silently reduce Weird's 2–3 events or It's Over's 2–3 disasters. All instances share the round's aggregate spawn, effects and debris budgets.

## Maps (3)

| Proposed Id | Name | Coin multiplier | XP multiplier | Droid spawn rate | Eligible droids |
|---|---|---:|---:|---:|---|
| baseplate | Baseplate | 1.5 | 1.25 | 1.0 | regular, chaser, range |
| classic_house | Classic House | 1.0 | 1.0 | 1.0 | regular, chaser, range, noob |
| the_town | The Town | 1.0 | 1.0 | 1.5 | regular, chaser, range, worker, police |

SpawnWeight is unspecified; provisional positive fixture weights must be labeled. Three primitive templates pass the asset validator. Voting selects 3 without replacement; leaving a pad retains a vote, changing pads replaces it, ties are uniform random.

## Droids (7)

| Id | Weight | HP | Proposed base XP | Melee | Special |
|---|---:|---:|---:|---|---|
| regular | 90 | 100 | 20 | 5 damage / 1 s | Basic chase |
| chaser | 70 | 100 | 20 | 5 / 1 s | Lunge within 20 studs; stun + ragdoll on hit; sit immobile 3 s; 30 s lunge cooldown |
| range | 25 | 50 | 10 | 2 / 0.2 s | Bullet attack, 20 stud range; firing tuning TODO(owner) |
| wind | Event only | 100 | 20 | 10; cadence TODO(owner) | Tornado only; BulletImmune |
| noob | 75 | 300 | 60 | 5 / 1 s | Classic House only |
| worker | 55 | 150 | 30 | 10 / 2 s | Paper 20 damage, 30 stud range, 15 s cooldown; Town only |
| police | 15 | 120 | 24 | 15 / 1 s | Shock stun 5 s, 30 s cooldown; range TODO(owner); Town only |

Weights are relative within eligible pools. Each droid independently respawns after 10 s at a different spawn with configured distance policy. Proposed XP tuning is `Droid.XP = 0.2 × baseHP` (D-21); these values were not supplied by the brief.

The boss is a Regular Droid with **HP ×50 = 5000**, a larger primitive rig, and the **same brain, 5 damage and 1-second melee cadence** (D-16). Proposed uniform size scale is **2**; the owner approved a bigger size, not this exact scale. No additional phases, abilities, damage increase or active-player-count HP scaling. One definition supplies one Big Boss or two independent It's Over bosses, with distinct entity identities. Proposed boss base XP is an explicit **100 XP override**, independent of scaled HP, equivalent to five ordinary Regular kill budgets; each boss has its own shared reward pool (D-05). HP ×50 does not imply XP ×50. Allied Regular Droids reuse faction-filtered AI, with cap/lifetime TODO(owner).

## Gears (9)

| Id | Name | Category | Acquisition (coins unless stated) | Damage | Ammo loaded/reserve | Strategy / ability |
|---|---|---|---|---:|---|---|
| push | Push | Melee | 100 | 5 | — | Minor knockback |
| classic_sword | Classic Roblox Sword | Melee | 250 | 15 | — | Basic melee |
| fish_sword | Fish Sword | Melee | 700 | 15 | — | Knockback every hit |
| hunter_rifle | Hunter Rifle | Gun | 1500 | 40 | 1/5 | Server FastCast |
| ak47 | AK47 | Gun | 7500 | 4 | 30/60 | Server FastCast |
| lightsaber | Lightsaber | Melee | Wheel only | 50 | — | Ability E: allied Regular Droid, 40 s cooldown |
| crystal_laser_cannon | Crystal Laser Cannon | Gun | Wheel only | 10 | 50/150 | Server FastCast |
| green_balloon | Green Balloon | Booster | 5000 | — | — | High jump; multiplier TODO(owner) |
| speed_coil | Speed Coil | Booster | 3500 | — | — | WalkSpeed ×2 subject to D-26 strongest-source rule/cap |

UsagePolicy supports Unlimited/Cooldown/OncePerRound; choose per definition with explicit configuration. Missing melee cadence, gun fire rates/reload/projectile values and knockback strengths are not inferred here. Three gear slots maximum; grants only at round start and no use in lobby.

## Utilities (4)

| Id | Unit price | Uses / round | Effect | Cooldown |
|---|---:|---|---|---:|
| ammo_box | 50 | 3 | +1 magazine to equipped ranged gear reserve; Ranger ×2; every class can use | 15 s |
| bloxy_cola | 50 | Inventory-bounded | WalkSpeed ×2 for 10 s, subject to D-26 strongest-source rule/cap | 20 s |
| landmine | 150 | 5 | Explodes on valid step; damage/radius TODO(owner) | 10 s |
| turret | 750 | 2 | Targetable auto-turret, 1000 HP; damage/range/ROF TODO(owner) | 10 s |

Inventory cap 100 per utility; purchases at cap reject, grants clamp. Use consumes persisted count server-side, with atomic cooldown/use limits. Utilities do not consume gear slots.

## Armours (3) and classes (3)

| Armour Id | Acquisition | Normalized effects |
|---|---|---|
| normal_vest | 1500 coins | DamageTaken ×0.80; MaxHP +200 |
| ghost_vest | 22222 coins | DamageTaken ×1.50; WalkSpeed ×3; transparent character |
| overseer_vest | Unobtainable; admin grant only | DamageTaken ×0.85; DamageDealt ×2; follower eye turret |

| Class Id | Price | Effects |
|---|---:|---|
| none | Free | None |
| warrior | 1200 | Melee damage ×2; MaxHP +10% |
| ranger | 2300 | Gun damage ×2; Ammo Box magazine addition ×2 |

Gears/armours/classes are unique one-time purchases. One armour/class equipped. Define and test additive/multiplicative stat layer order for other stats. D-26 delegates a speed-stack nerf: proposed speed composition takes the **strongest active positive multiplier**, then caps WalkSpeed at **32 studs/s** with a proposed baseline of **16 studs/s**. Coil or Cola yields 32; both remain 32; Ghost's ×3 is capped at 32; all three still yield 32. The ×2/×3 source effects remain definitions, but their effective movement follows this rule. Removing or expiring a source recomputes from remaining sources; stun still immobilizes rather than being overridden by a boost. Rule, baseline and cap are tuning proposals, not explicit owner-approved constants. Follower model remains primitive, not final design.

## Wheel and products

| Active reward | Relative weight | Proposed normalized chance (%) |
|---|---:|---:|
| +1 Bloxy Cola | 25 | 27.1739 |
| ×2 coins, 5 min | 20 | 21.7391 |
| ×2 coins, 15 min | 12 | 13.0435 |
| ×2 XP, 5 min | 20 | 21.7391 |
| ×2 XP, 15 min | 12 | 13.0435 |
| Lightsaber | 2.5 | 2.7174 |
| Crystal Laser Cannon | 0.5 | 0.5435 |

Gems are deferred entirely (D-18): no gem schema field, replica/UI, grant or sink. The source's `+5 Gems / 8%` entry is a **historical reserved, disabled entry**, not selectable config. The seven active weights total **92**. Provisional sampling normalizes `weight / 92` (display percentages rounded above); **final distribution is pending economy review**. No replacement reward or automatic redistribution to one entry is approved.

Free-spin cooldown is **900 seconds of connected in-game playtime** (D-13). Persist `FreeSpinRemainingSeconds`, not an offline-expiring `NextFreeSpinAt`. The server decrements remaining time only while connected, including Lobby and AFK; leaving/shutdown saves the remainder, and offline time changes nothing. Rejoin resumes from that remainder. Zero means eligible until an atomic free-spin claim resets the cooldown to 900; first-profile eligibility and crash-checkpoint policy must be explicit before the affected implementation. Paid spin product: 25 Robux; a paid spin must not accidentally consume/reset the free cooldown. Server commits result before client presentation. Duplicate unique gear converts to owner-tunable coin compensation. Boost duration stacking remains unresolved.

Donation products: **5, 10, 50, 100, 500, 1000, 5000, 10000 Robux** (8 products). Pick Token product: **69 Robux**, map + scenario, FIFO one per next eligible round. Combined with paid spin, there are 10 known dev-product definitions. Product IDs default 0 (unset/guarded); no actual IDs/gamepasses are invented. Do not create or publish products during foundation development without separate authorization.

## Lobby, dialogue and boards

- Four Top 50 boards: Most Kills, Most Level, Most Survives, Donation.
- AFK area, class/shop/gamepass primitives, spectate living players after death, separate utility actions.
- Chair, sofa and obby are removed from agent implementation scope (D-17); the owner will design these independently. Do not add placeholders, interaction handlers, costs or reward logic for them.
- Four NPC placeholders: Helper Robot (`helper_robot`), NomeKM the evil dev (`nomekm`), Mrs.Rin (`mrs_rin`), Somchai (`somchai`). Owner authors dialogue.
- Dialogue choices: Chat white; Quest yellow; CompleteQuest green (gray disabled); Secret white, hidden until discovered; Leave red. These are functional semantics, not a visual theme.
- Minimal quest objectives: KillDroid, SurviveRound, Custom. Unknown content is owner TODO, not generated narrative.
- Admin commands: forceScenario, forceMap, forceEvent, spawnDroid, giveCoins, giveItem, skipPhase, killAllDroids, godMode, setTimer. UserId-gated, disabled in production.

## Pure formula baseline

```text
DroidCap = floor(50 × Map.DroidSpawnRate × Scenario.DroidMultiplier × event spawn modifiers)
SumBonus = 1 + (map multiplier − 1) + (Scenario.RewardMultiplier − 1)
DamageRatio = floor(killerDamage / droidMaxHP × 100) / 100; sole damager = 1.00
NonBossKillXP = Droid.XP × CombinedMult(xp) × DamageRatio × PersonalXpBoost
NonBossKillCoins = NonBossKillXP / 2 × PersonalCoinBoost
BossBasePoolXP = Boss.XP × CombinedMult(xp)
BossShare(player) = actualPositiveDamage(player) / sum(actualPositiveDamage(all contributors))
BossXP(player) = BossBasePoolXP × BossShare(player) × PersonalXpBoost(player)
BossCoins(player) = BossXP(player) / 2 × PersonalCoinBoost(player)
SurvivalCoins = 100 × CombinedMult(coin) × PersonalCoinBoost
Proposed Level = 1 + floor(totalXP / 100); next-level cost = 100 XP
```

**Non-boss rewards are KillerOnly** and preserve the source's truncated killer DamageRatio; assistants still contribute to MVP statistics. **Boss rewards share one base pool per boss proportionally across actual positive damage contributors** (D-05), without requiring the final hit. Credit HP actually lost and exclude overkill. Calculate all shares from one immutable ledger snapshot; do not issue a full pool independently to every contributor. Personal boosts apply after splitting and can legitimately raise boosted payouts beyond the unboosted pool. The non-boss 2-decimal truncation does not silently become a boss share-rounding policy; reward quantization and disconnected/environmental/ally attribution require explicit contracts. KillCoins' inheritance of XP factors is preserved for review (R-04); do not silently substitute map CoinMultiplier.

### Proposed linear leveling balance (D-21)

The owner chose linear leveling and delegated balancing against enemy XP. Proposed **100 XP per level** and the HP-based XP values above are starting tuning for later playtests. These examples include existing SumBonus/map/scenario/reward rules, assume no personal boosts and show unrounded XP; final fractional-credit/coin quantization remains pending.

| Illustrative case | Effective XP | Pacing from XP = 0 (Level 1) |
|---|---:|---|
| House Regular scenario, sole Regular killer | 20 | 5 kills → 100 XP, Level 2 |
| Baseplate Regular scenario, sole Regular killer | 25 (`20 × 1.25`) | 4 kills → 100 XP, Level 2 |
| House Regular scenario, sole Range killer | 10 | 10 kills → 100 XP, Level 2 |
| House Regular scenario, sole Noob killer | 60 | 2 kills → 120 XP, Level 2 + 20 progress |
| House Regular, Regular killer credited 59.78% damage | 11.8 (`20 × 0.59`) | 9 kills → 106.2 XP, Level 2 + 6.2 progress |
| House Big Boss, sole contributor | 175 (`100 × 1.75`) | Level 2 + 75 progress from this boss's one 175 XP pool |
| Baseplate Big Boss, two contributors with 50/50 actual damage | 100 each (`100 × 2 × 0.5`) | Each gains 1 level from this boss's one 200 XP pool |
| Town It's Over, two bosses, four equal contributors to each | 75 per boss/person (`100 × 3 × 0.25`) | Both bosses yield 150/person, Level 2 + 50 progress |

An XP ×2 boost doubles these XP values before level computation; KillCoins also inherits that boost under the literal source formula. The proposed boss override avoids a 1750 XP solo House Big Boss windfall (17.5 level budgets) from applying the ordinary XP/HP rule to scaled HP. Boss scenarios are rare (4% / 1%); playtesting must measure the 240-second boss win rate, contributor counts, kills/round and boosts before accepting tuning. No survival XP has been invented.

Cap fixtures without event modifiers:

| Map spawn rate | Regular | Not Regular | Weird | Big Boss | It's Over |
|---|---:|---:|---:|---:|---:|
| 1.0 (Baseplate/House) | 50 | 60 | 60 | 75 | 90 |
| 1.5 (Town) | 75 | 90 | 90 | 112 | 135 |

Max reference cap is 135 before additional event modifiers. Perf tests must also exercise configured event-modified worst case; boss/ally/structure counting policy must be documented rather than hidden in code.
