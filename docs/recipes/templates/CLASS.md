# ClassDefinition — schematic template

Related recipe: [Add Class](../ADD_CLASS.md).

This is a **non-executable planning template**. Angle-bracket fields must be replaced with owner-approved values and actual Contracts v1 field names. The final definition must be a strict Luau ModuleScript returning typed, validated data. No price/damage/time placeholder below is adopted balance. Optional fields should be omitted when the selected strategy does not use them.

```text
Id = "<new_class_id>"
DisplayName = "<owner_name>"
Acquisition = { Kind = "Purchase", PriceCoins = <approved_price> }
BehaviorId = "<existing_class_strategy>"
Stats = {
  MeleeDamageMultiplier = <approved_multiplier_if_needed>,
  GunDamageMultiplier = <approved_multiplier_if_needed>,
  MaxHpMultiplier = <approved_multiplier_if_needed>,
  AmmoBoxMultiplier = <approved_multiplier_if_needed>,
}
Params = <typed_strategy_params>
```

Any future speed modifier participates in the shared D-26 source-tagged policy rather than bypassing it. Proposed strongest-source composition and 32 studs/s cap (base 16) await verification; other stat multipliers retain their own approved composition. This template does not add a speed effect to the existing classes.

Use the canonical strategy schema; do not insert arbitrary functions or `any` dictionaries to bypass validation. Server-only hooks stay behind registered IDs. Freeze definitions through the registry. Asset references must satisfy [MODEL_CONTRACT](../../MODEL_CONTRACT.md).

Before enabling: no unresolved placeholders/TODO tuning masquerading as final balance, no duplicate IDs, all references valid, exact source numbers preserved for existing content, and relevant acceptance tests/evidence recorded.
