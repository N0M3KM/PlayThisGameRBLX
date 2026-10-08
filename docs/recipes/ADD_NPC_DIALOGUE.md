# Add a NPC Dialogue

Owner: workstream H. Related task: WS-H-01. Input: frozen DialogueGraph, dialogue condition/action IDs, valid assets. Output: a discovered definition that works in NPC sessions, quest progress and client choices without core edits.

Target: `src/shared/Config/Dialogue/<Id>.luau`; tests under `tests/unit/npc` and `tests/integration/npc`. See [template](templates/NPC_DIALOGUE.md), [catalog](../CONTENT-CATALOG.md), [contracts](../CONTRACTS.md) and [asset contract](../MODEL_CONTRACT.md).

## Checklist

- [ ] Owner writes text; keep graph content TODO(owner) until supplied.
- [ ] Use stable NPC/node/choice IDs and existing trusted server actions/conditions.
- [ ] Provide a primitive NPC root with NpcId and registered interaction distance.
- [ ] Validate dead links/unreachable nodes; test proximity/stale session, hidden secrets, completion availability and private persistent flags.
- [ ] Replace all schematic template placeholders; verify exact fields against exported types.
- [ ] Registry/config/asset validation, domain tests, format/lint/type checks and Rojo build pass.
- [ ] Demonstrate gameplay or durable entitlement with required real-engine evidence; record cleanup and limitations.
- [ ] Record required ADR/approval; no unapproved dependency/schema/balance change or git commit/push.

## Negative cases

Reject duplicate/unknown IDs, wrong types/nonfinite values, missing referenced handlers/assets, wrong player state, stale requests and failed cleanup. Add category-specific failure cases from [TEST-PLAN](../TEST-PLAN.md).

## Data-only boundary

Reuse an existing dialogue condition/action IDs. If a new strategy/schema field is required, open a separate implementation task/CCR instead of editing a central dispatch list. Asset changes stay primitive unless the owner authorizes design.
