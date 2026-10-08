# GearDefinition — schematic template

Related recipe: [Add Gear](../ADD_GEAR.md).

This is a **non-executable planning template**. Angle-bracket fields must be replaced with owner-approved values and actual Contracts v1 field names. The final definition must be a strict Luau ModuleScript returning typed, validated data. No price/damage/time placeholder below is adopted balance. Optional fields should be omitted when the selected strategy does not use them.

```text
Id = "<new_gear_id>"
DisplayName = "<owner_name>"
Category = "Melee" | "Gun" | "Booster"
Acquisition = { Kind = "Purchase", PriceCoins = <approved_price> }
  | { Kind = "Wheel" } | { Kind = "Unobtainable" }
UsagePolicy = "Unlimited" | "Cooldown" | "OncePerRound"
CooldownSeconds = <approved_seconds_if_needed>
BehaviorId = "<existing_gear_strategy>"
ToolTemplate = "<validated_asset_reference>"
Damage = <approved_damage_if_needed>
Ammo = { MagazineSize = <approved_size>, ReserveAmmo = <approved_reserve> } -- Gun only
Passives = { { Id = "<existing_passive>", Params = <typed_params> } }
Active = { AbilityId = "<existing_ability>", Params = <typed_params> } -- optional
```

Use the canonical strategy schema; do not insert arbitrary functions or `any` dictionaries to bypass validation. Server-only hooks stay behind registered IDs. Freeze definitions through the registry. Asset references must satisfy [MODEL_CONTRACT](../../MODEL_CONTRACT.md).

Movement gear registers a scoped modifier source, consumed by D-26's proposed strongest-active-buff composition with a 32 studs/s final cap (base 16). Speed Coil retains its source times-2 modifier; it must not multiply with Cola/armour or write unowned character speed. Keep stun precedence and source-removal tests in the shared stat strategy.

Before enabling: no unresolved placeholders/TODO tuning masquerading as final balance, no duplicate IDs, all references valid, exact source numbers preserved for existing content, and relevant acceptance tests/evidence recorded.
