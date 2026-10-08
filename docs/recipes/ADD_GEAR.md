# Add a Gear

Owner: workstream C. Related task: WS-C-07. Input: frozen GearDefinition, Gear strategy, valid assets. Output: a discovered definition that works in gear grant, loadout, hotbar and shop without core edits.

Target: `src/shared/Config/Gears/<Id>.luau`; tests under `tests/unit/combat` and `tests/integration/combat`. See [template](templates/GEAR.md), [catalog](../CONTENT-CATALOG.md), [contracts](../CONTRACTS.md) and [asset contract](../MODEL_CONTRACT.md).

## Checklist

- [ ] Choose an existing Gear/Passive/Ability strategy; a new mechanic is a separate C/F task.
- [ ] Use an owner-approved purchase price or wheel/admin acquisition; unique purchase and max three gear slots still apply.
- [ ] Provide a primitive tool satisfying melee or gun attachment rules.
- [ ] Verify server damage/ammo/cooldown, loadout snapshot, lobby denial, and automatically generated UI.
- [ ] Movement gear uses the D-26 source-tagged speed policy: strongest active positive multiplier, proposed cap 32 studs/s at base 16, recomputed on removal. Test coil with Cola/armour and stun precedence; no times-12 stack or direct unscoped WalkSpeed writes.
- [ ] Replace all schematic template placeholders; verify exact fields against exported types.
- [ ] Registry/config/asset validation, domain tests, format/lint/type checks and Rojo build pass.
- [ ] Demonstrate gameplay or durable entitlement with required real-engine evidence; record cleanup and limitations.
- [ ] Record required ADR/approval; no unapproved dependency/schema/balance change or git commit/push.

## Negative cases

Reject duplicate/unknown IDs, wrong types/nonfinite values, missing referenced handlers/assets, wrong player state, stale requests and failed cleanup. Add category-specific failure cases from [TEST-PLAN](../TEST-PLAN.md).

## Data-only boundary

Reuse an existing Gear strategy. If a new strategy/schema field is required, open a separate implementation task/CCR instead of editing a central dispatch list. Asset changes stay primitive unless the owner authorizes design.
