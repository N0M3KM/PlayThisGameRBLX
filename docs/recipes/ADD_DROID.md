# Add a Droid

Owner: workstream D. Related task: WS-D-06. Input: frozen DroidDefinition, BT subtree/ability, valid assets. Output: a discovered definition that works in eligible map/event pools and AI without core edits.

Target: `src/shared/Config/Droids/<Id>.luau`; tests under `tests/unit/droids` and `tests/integration/droids`. See [template](templates/DROID.md), [catalog](../CONTENT-CATALOG.md), [contracts](../CONTRACTS.md) and [asset contract](../MODEL_CONTRACT.md).

## Checklist

- [ ] Reuse existing BT/ability IDs and a validated primitive rig.
- [ ] Declare spawn eligibility; event-only types must not enter ordinary map pools.
- [ ] Use the Phase 0 reviewed EligibleMapIds extension rule (R-20) to enter an existing map through this definition alone; do not count an unused definition or second map edit as a one-file proof.
- [ ] Verify independent 10 s respawn/different spawn, server ownership, cap/faction, stale worker decision and pool reset.
- [ ] Set explicit base XP using D-21 linear-level pacing tests. Ordinary XP = 0.2 * baseHP and 100 XP/level are proposals; the boss has a separate proposed 100 base-XP override, so its HP scaling never silently scales its reward.
- [ ] Use D-05 KillerOnly for non-boss death rewards; boss-event contribution sharing is E/B policy. Keep actual-damage/MVP facts available for both paths.
- [ ] Replace all schematic template placeholders; verify exact fields against exported types.
- [ ] Registry/config/asset validation, domain tests, format/lint/type checks and Rojo build pass.
- [ ] Demonstrate gameplay or durable entitlement with required real-engine evidence; record cleanup and limitations.
- [ ] Record required ADR/approval; no unapproved dependency/schema/balance change or git commit/push.

## Negative cases

Reject duplicate/unknown IDs, wrong types/nonfinite values, missing referenced handlers/assets, wrong player state, stale requests and failed cleanup. Add category-specific failure cases from [TEST-PLAN](../TEST-PLAN.md).

## Data-only boundary

Reuse an existing BT subtree/ability. If a new strategy/schema field is required, open a separate implementation task/CCR instead of editing a central dispatch list. Asset changes stay primitive unless the owner authorizes design.

The v0.1 boss is owned by E and reuses Regular Droid data/rig/brain with HP times 50 (5000), larger size (uniform scale 2 proposed) and the same existing attack/abilities. Do not add phases, attacks, player-count HP scaling or a competing boss brain under D. Validate scaled attachments, pathing clearance and pool reset through [MODEL_CONTRACT](../MODEL_CONTRACT.md), and preserve distinct runtime IDs when two bosses are required.
