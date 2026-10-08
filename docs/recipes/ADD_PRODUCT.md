# Add a Product

Owner: workstream G. Related task: WS-G-01. Input: frozen ProductDefinition, receipt grant handler, valid assets. Output: a discovered definition that works in monetization registry and durable entitlement without core edits.

Target: `src/shared/Config/Products/<Id>.luau`; tests under `tests/unit/lobby` and `tests/integration/lobby`. See [template](templates/PRODUCT.md), [catalog](../CONTENT-CATALOG.md), [contracts](../CONTRACTS.md) and [asset contract](../MODEL_CONTRACT.md).

## Checklist

- [ ] Do not invent a product/pass, price or benefits; known v0.1 prices remain exact.
- [ ] ProductId 0 stays guarded and cannot prompt or grant.
- [ ] Choose existing idempotent receipt grant handler for dev products; gamepasses use cached ownership, not repeatable receipt grants.
- [ ] Verify unloaded profile/save failure/retry/concurrency/compaction, durable grant before PurchaseGranted and correct donation/credit mapping.
- [ ] Never add gem entitlement/grant handlers in v0.1 (D-18). Paid-spin receipts credit their own durable entitlement and leave the persisted connected-playtime free timer unchanged (D-13); test disconnect/retry with both balances present.
- [ ] Replace all schematic template placeholders; verify exact fields against exported types.
- [ ] Registry/config/asset validation, domain tests, format/lint/type checks and Rojo build pass.
- [ ] Demonstrate gameplay or durable entitlement with required real-engine evidence; record cleanup and limitations.
- [ ] Record required ADR/approval; no unapproved dependency/schema/balance change or git commit/push.

## Negative cases

Reject duplicate/unknown IDs, wrong types/nonfinite values, missing referenced handlers/assets, wrong player state, stale requests and failed cleanup. Add category-specific failure cases from [TEST-PLAN](../TEST-PLAN.md).

## Data-only boundary

Reuse an existing receipt grant handler. If a new strategy/schema field is required, open a separate implementation task/CCR instead of editing a central dispatch list. Asset changes stay primitive unless the owner authorizes design.
