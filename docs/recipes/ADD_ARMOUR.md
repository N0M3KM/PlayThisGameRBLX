# Add a Armour

Owner: workstream F. Related task: WS-F-04. Input: frozen ArmourDefinition, Armour strategy, valid assets. Output: a discovered definition that works in equip, stat stack and shop without core edits.

Target: `src/shared/Config/Armours/<Id>.luau`; tests under `tests/unit/items` and `tests/integration/items`. See [template](templates/ARMOUR.md), [catalog](../CONTENT-CATALOG.md), [contracts](../CONTRACTS.md) and [asset contract](../MODEL_CONTRACT.md).

## Checklist

- [ ] Retain unique ownership and one equipped armour.
- [ ] Separate DamageTaken from DamageDealt as normalized in D-09.
- [ ] Use source-tagged stat changes; primitive optional follower/accessory only.
- [ ] Verify D-26 strongest-active-speed-buff composition rather than products, proposed 32 studs/s cap against base 16, stronger-source removal/expiry, stun precedence and rapid respawn. These numeric values await pacing/device tests.
- [ ] Verify other modifiers, admin-only guard where needed and transparency/follower cleanup.
- [ ] Replace all schematic template placeholders; verify exact fields against exported types.
- [ ] Registry/config/asset validation, domain tests, format/lint/type checks and Rojo build pass.
- [ ] Demonstrate gameplay or durable entitlement with required real-engine evidence; record cleanup and limitations.
- [ ] Record required ADR/approval; no unapproved dependency/schema/balance change or git commit/push.

## Negative cases

Reject duplicate/unknown IDs, wrong types/nonfinite values, missing referenced handlers/assets, wrong player state, stale requests and failed cleanup. Add category-specific failure cases from [TEST-PLAN](../TEST-PLAN.md).

## Data-only boundary

Reuse an existing Armour strategy. If a new strategy/schema field is required, open a separate implementation task/CCR instead of editing a central dispatch list. Asset changes stay primitive unless the owner authorizes design.
