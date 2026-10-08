# Add a Scenario

Owner: workstream A. Related task: WS-A-05. Input: frozen ScenarioDefinition, ScenarioDirector selection policy, valid assets. Output: a discovered definition that works in round planning, cap and rewards without core edits.

Target: `src/shared/Config/Scenarios/<Id>.luau`; tests under `tests/unit/match` and `tests/integration/match`. See [template](templates/SCENARIO.md), [catalog](../CONTENT-CATALOG.md), [contracts](../CONTRACTS.md) and [asset contract](../MODEL_CONTRACT.md).

## Checklist

- [ ] Existing five scenarios/weights remain unchanged unless the owner approves a balance change.
- [ ] Use existing scenario/event/boss selection behavior; ensure counts can be satisfied.
- [ ] Apply the confirmed 240-second round and 240-second boss deadline. Preserve one/two required boss identities and all-bosses-dead resolution.
- [ ] D-16 limits v0.1 to Tornado. Validate proposed repeated scoped Tornado instances for multi-slot scenarios with an aggregate budget; do not reduce source counts or invent named event/disaster stubs.
- [ ] Boss selection reuses Regular HP times 50 and larger size without extra phases/abilities. Check contribution-shared boss rewards independently from non-boss KillerOnly rewards.
- [ ] Declare whether selection changes relative probabilities and record ADR/approval.
- [ ] Verify seeded selection, map-independent rates, all outcome/deadline rules and cap/reward math.
- [ ] Replace all schematic template placeholders; verify exact fields against exported types.
- [ ] Registry/config/asset validation, domain tests, format/lint/type checks and Rojo build pass.
- [ ] Demonstrate gameplay or durable entitlement with required real-engine evidence; record cleanup and limitations.
- [ ] Record required ADR/approval; no unapproved dependency/schema/balance change or git commit/push.

## Negative cases

Reject duplicate/unknown IDs, wrong types/nonfinite values, missing referenced handlers/assets, wrong player state, stale requests and failed cleanup. Add category-specific failure cases from [TEST-PLAN](../TEST-PLAN.md).

## Data-only boundary

Reuse an existing ScenarioDirector selection policy. If a new strategy/schema field is required, open a separate implementation task/CCR instead of editing a central dispatch list. Asset changes stay primitive unless the owner authorizes design.
