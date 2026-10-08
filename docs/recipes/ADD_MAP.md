# Add a Map

Owner: workstream A. Related task: WS-A-03. Input: frozen MapDefinition, validated map template, valid assets. Output: a discovered definition that works in weighted voting, spawns and rewards without core edits.

Target: `src/shared/Config/Maps/<Id>.luau`; tests under `tests/unit/match` and `tests/integration/match`. See [template](templates/MAP.md), [catalog](../CONTENT-CATALOG.md), [contracts](../CONTRACTS.md) and [asset contract](../MODEL_CONTRACT.md).

## Checklist

- [ ] Create only primitive placeholder geometry unless final model work is separately authorized.
- [ ] Include PlayerSpawns, at least two DroidSpawns and safe RecoveryPoint with exact asset schema.
- [ ] Reference existing eligible droids; weights/multipliers are explicit approved tuning.
- [ ] Verify auto-discovery in voting, clone/validate/teleport, cap/reward math, streaming absence and clean unload/restoration.
- [ ] Replace all schematic template placeholders; verify exact fields against exported types.
- [ ] Registry/config/asset validation, domain tests, format/lint/type checks and Rojo build pass.
- [ ] Demonstrate gameplay or durable entitlement with required real-engine evidence; record cleanup and limitations.
- [ ] Record required ADR/approval; no unapproved dependency/schema/balance change or git commit/push.

## Negative cases

Reject duplicate/unknown IDs, wrong types/nonfinite values, missing referenced handlers/assets, wrong player state, stale requests and failed cleanup. Add category-specific failure cases from [TEST-PLAN](../TEST-PLAN.md).

## Data-only boundary

Reuse an existing validated map template. If a new strategy/schema field is required, open a separate implementation task/CCR instead of editing a central dispatch list. Asset changes stay primitive unless the owner authorizes design.
