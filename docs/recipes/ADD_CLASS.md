# Add a Class

Owner: workstream F. Related task: WS-F-05. Input: frozen ClassDefinition, Class strategy, valid assets. Output: a discovered definition that works in selection, damage/stat modifiers and shop without core edits.

Target: `src/shared/Config/Classes/<Id>.luau`; tests under `tests/unit/items` and `tests/integration/items`. See [template](templates/CLASS.md), [catalog](../CONTENT-CATALOG.md), [contracts](../CONTRACTS.md) and [asset contract](../MODEL_CONTRACT.md).

## Checklist

- [ ] Reuse an existing stat/class strategy; preserve None free and one equipped class.
- [ ] Declare typed modifier layers and owner-approved price.
- [ ] Do not restrict Ammo Box to Ranger; Ranger's existing multiplier is a separate effect.
- [ ] Verify selection generated from registry, purchase/round lock, respawn cleanup and composition with armour/gear.
- [ ] Route any movement buff through the D-26 source-tagged speed policy; never multiply it with coil/cola/armour into the old times-12 stack. Proposed strongest-source composition/cap must preserve stun precedence and recompute on removal.
- [ ] Replace all schematic template placeholders; verify exact fields against exported types.
- [ ] Registry/config/asset validation, domain tests, format/lint/type checks and Rojo build pass.
- [ ] Demonstrate gameplay or durable entitlement with required real-engine evidence; record cleanup and limitations.
- [ ] Record required ADR/approval; no unapproved dependency/schema/balance change or git commit/push.

## Negative cases

Reject duplicate/unknown IDs, wrong types/nonfinite values, missing referenced handlers/assets, wrong player state, stale requests and failed cleanup. Add category-specific failure cases from [TEST-PLAN](../TEST-PLAN.md).

## Data-only boundary

Reuse an existing Class strategy. If a new strategy/schema field is required, open a separate implementation task/CCR instead of editing a central dispatch list. Asset changes stay primitive unless the owner authorizes design.
