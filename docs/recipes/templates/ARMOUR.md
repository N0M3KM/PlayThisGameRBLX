# ArmourDefinition — schematic template

Related recipe: [Add Armour](../ADD_ARMOUR.md).

This is a **non-executable planning template**. Angle-bracket fields must be replaced with owner-approved values and actual Contracts v1 field names. The final definition must be a strict Luau ModuleScript returning typed, validated data. No price/damage/time placeholder below is adopted balance. Optional fields should be omitted when the selected strategy does not use them.

```text
Id = "<new_armour_id>"
DisplayName = "<owner_name>"
Acquisition = { Kind = "Purchase", PriceCoins = <approved_price> }
  | { Kind = "Unobtainable" }
BehaviorId = "<existing_armour_strategy>"
Stats = {
  DamageTakenMultiplier = <approved_multiplier>,
  DamageDealtMultiplier = <approved_multiplier_if_needed>,
  MaxHpAdd = <approved_value_if_needed>,
  WalkSpeedMultiplier = <approved_multiplier_if_needed>, -- speed source, not a direct product
}
Params = <typed_strategy_params>
```

Movement params identify a scoped source for D-26. Proposed composition is the strongest active positive multiplier, then final cap 32 studs/s at base 16; stun has precedence. Ghost's source multiplier times 3 remains declared but follows this proposed effective-speed cap. Do not embed an independently applied WalkSpeed product, and test source removal/expiry/respawn before accepting numeric tuning.

Use the canonical strategy schema; do not insert arbitrary functions or `any` dictionaries to bypass validation. Server-only hooks stay behind registered IDs. Freeze definitions through the registry. Asset references must satisfy [MODEL_CONTRACT](../../MODEL_CONTRACT.md).

Before enabling: no unresolved placeholders/TODO tuning masquerading as final balance, no duplicate IDs, all references valid, exact source numbers preserved for existing content, and relevant acceptance tests/evidence recorded.
