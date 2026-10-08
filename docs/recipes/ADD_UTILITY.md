# Add a Utility

Owner: workstream F. Related task: WS-F-01. Input: frozen UtilityDefinition, Utility strategy, valid assets. Output: a discovered definition that works in consumption, utility actions and shop without core edits.

Target: `src/shared/Config/Utilities/<Id>.luau`; tests under `tests/unit/items` and `tests/integration/items`. See [template](templates/UTILITY.md), [catalog](../CONTENT-CATALOG.md), [contracts](../CONTRACTS.md) and [asset contract](../MODEL_CONTRACT.md).

## Checklist

- [ ] Choose a registered use/placement strategy and declared params schema.
- [ ] Retain per-type inventory cap 100; utilities use separate input actions, not gear slots.
- [ ] Prepare required placement/root/muzzle attachment if deployable.
- [ ] Verify persisted decrement, simultaneous-use reservations, cap/use/cooldown and rollback on placement/save failure.
- [ ] For speed buffs such as Bloxy Cola, register a timed source in the D-26 strongest-active-buff policy; proposed cap is 32 studs/s at base 16. Verify coil/armour combinations, expiry order, stun precedence and character/round cleanup rather than applying direct multiplicative WalkSpeed writes.
- [ ] Replace all schematic template placeholders; verify exact fields against exported types.
- [ ] Registry/config/asset validation, domain tests, format/lint/type checks and Rojo build pass.
- [ ] Demonstrate gameplay or durable entitlement with required real-engine evidence; record cleanup and limitations.
- [ ] Record required ADR/approval; no unapproved dependency/schema/balance change or git commit/push.

## Negative cases

Reject duplicate/unknown IDs, wrong types/nonfinite values, missing referenced handlers/assets, wrong player state, stale requests and failed cleanup. Add category-specific failure cases from [TEST-PLAN](../TEST-PLAN.md).

## Data-only boundary

Reuse an existing Utility strategy. If a new strategy/schema field is required, open a separate implementation task/CCR instead of editing a central dispatch list. Asset changes stay primitive unless the owner authorizes design.
