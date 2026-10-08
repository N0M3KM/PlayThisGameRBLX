# Add a Event / Disaster

Scope note (D-16): Tornado is the only v0.1 event/disaster implementation. Do not create additional named stubs or invented event content. This recipe also describes a future extension, subject to its own authorized task. The proposed v0.1 policy repeats Tornado instances to satisfy the existing multi-event/disaster scenario counts; repeat selection and slot/category mapping must pass Phase 0 validation before adoption.

Owner: workstream E. Related task: WS-E-03. Input: frozen EventDefinition, Event lifecycle handler, valid assets. Output: a discovered definition that works in scenario selection and scoped modifiers without core edits.

Target: `src/shared/Config/Events/<Id>.luau`; tests under `tests/unit/events` and `tests/integration/events`. See [template](templates/EVENT.md), [catalog](../CONTENT-CATALOG.md), [contracts](../CONTRACTS.md) and [asset contract](../MODEL_CONTRACT.md).

## Checklist

- [ ] Select an existing scoped handler/subtree; server hooks are resolved by ID, not shared callback functions.
- [ ] Provide positive weight/category and an explicit scenario slot/count policy. For the proposed Tornado-only repeat policy, count distinct scoped instances rather than distinct definitions; preserve source counts without fabricating new named definitions.
- [ ] Keep event balance and names owner-controlled; no final effects/art design.
- [ ] Verify Start/Tick/Stop, Stop twice, error isolation, cap modifiers, late-stop and teardown with zero resources.
- [ ] Repeated Tornado instances have distinct identities/scopes and share aggregate Wind/debris/performance limits; stopping one cannot stop another or restore its modifiers. Validate the existing two/three-slot scenario fixtures.
- [ ] Replace all schematic template placeholders; verify exact fields against exported types.
- [ ] Registry/config/asset validation, domain tests, format/lint/type checks and Rojo build pass.
- [ ] Demonstrate gameplay or durable entitlement with required real-engine evidence; record cleanup and limitations.
- [ ] Record required ADR/approval; no unapproved dependency/schema/balance change or git commit/push.

## Negative cases

Reject duplicate/unknown IDs, wrong types/nonfinite values, missing referenced handlers/assets, wrong player state, stale requests and failed cleanup. Add category-specific failure cases from [TEST-PLAN](../TEST-PLAN.md).

## Data-only boundary

Reuse an existing Event lifecycle handler. If a new strategy/schema field is required, open a separate implementation task/CCR instead of editing a central dispatch list. Asset changes stay primitive unless the owner authorizes design.
