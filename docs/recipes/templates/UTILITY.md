# UtilityDefinition — schematic template

Related recipe: [Add Utility](../ADD_UTILITY.md).

This is a **non-executable planning template**. Angle-bracket fields must be replaced with owner-approved values and actual Contracts v1 field names. The final definition must be a strict Luau ModuleScript returning typed, validated data. No price/damage/time placeholder below is adopted balance. Optional fields should be omitted when the selected strategy does not use them.

```text
Id = "<new_utility_id>"
DisplayName = "<owner_name>"
PriceCoins = <approved_unit_price>
BehaviorId = "<existing_utility_strategy>"
Template = "<validated_asset_reference>"
CooldownSeconds = <approved_seconds>
UsePolicy = { Kind = "PerRound", Maximum = <approved_uses> }
  | { Kind = "InventoryBounded" }
Params = <typed_strategy_params>
```

For a timed speed strategy, typed params must identify the owned buff source and duration. Bloxy Cola retains its source times-2 effect for 10 seconds, but D-26's proposed strongest-active-buff rule and 32 studs/s cap (base 16) govern the final speed. Do not reset a previously cached WalkSpeed on expiry; remove this source and recalculate from current character/state sources. Exact policy/cap remain proposed pending tests.

Use the canonical strategy schema; do not insert arbitrary functions or `any` dictionaries to bypass validation. Server-only hooks stay behind registered IDs. Freeze definitions through the registry. Asset references must satisfy [MODEL_CONTRACT](../../MODEL_CONTRACT.md).

Before enabling: no unresolved placeholders/TODO tuning masquerading as final balance, no duplicate IDs, all references valid, exact source numbers preserved for existing content, and relevant acceptance tests/evidence recorded.
