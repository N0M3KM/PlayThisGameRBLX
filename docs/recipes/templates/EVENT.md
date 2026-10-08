# EventDefinition — schematic template

Related recipe: [Add Event / Disaster](../ADD_EVENT.md).

This is a **non-executable planning template**. Angle-bracket fields must be replaced with owner-approved values and actual Contracts v1 field names. The final definition must be a strict Luau ModuleScript returning typed, validated data. No price/damage/time placeholder below is adopted balance. Optional fields should be omitted when the selected strategy does not use them.

```text
Id = "<new_event_id>"
DisplayName = "<owner_name>"
Category = "Event" | "Disaster"
Weight = <positive_relative_weight>
BehaviorId = "<existing_event_handler>"
DroidModifiers = <typed_modifier_params_if_used>
Params = <typed_handler_params>
```

Only Tornado is implemented for v0.1 (D-16); this generic template does not authorize more named event/disaster stubs. Proposed repetition is runtime selection policy, not duplicate definition files. Each selected Tornado receives a distinct instance ID/scope and consumes one scenario slot; all instances share aggregate Wind/debris/performance limits. Freeze the slot/category and repetition policy through Phase 0 validation before use.

Use the canonical strategy schema; do not insert arbitrary functions or `any` dictionaries to bypass validation. Server-only hooks stay behind registered IDs. Freeze definitions through the registry. Asset references must satisfy [MODEL_CONTRACT](../../MODEL_CONTRACT.md).

Before enabling: no unresolved placeholders/TODO tuning masquerading as final balance, no duplicate IDs, all references valid, exact source numbers preserved for existing content, and relevant acceptance tests/evidence recorded.
