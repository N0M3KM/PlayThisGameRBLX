# DroidDefinition — schematic template

Related recipe: [Add Droid](../ADD_DROID.md).

This is a **non-executable planning template**. Angle-bracket fields must be replaced with owner-approved values and actual Contracts v1 field names. The final definition must be a strict Luau ModuleScript returning typed, validated data. No price/damage/time placeholder below is adopted balance. Optional fields should be omitted when the selected strategy does not use them.

```text
Id = "<new_droid_id>"
DisplayName = "<owner_name>"
HP = <approved_hp>
XP = <explicit_base_xp> -- D-21 tuning; do not infer boss XP from scaled HP
SpawnWeight = <positive_relative_weight> -- omit ordinary-pool weight for event-only type
EligibleMapIds = { "<registered_map_id>" } -- proposed R-20; ordinary-pool extension only
Template = "<validated_rig_reference>"
BehaviorTreeId = "<existing_tree>"
Faction = "Hostile"
Traits = { "<existing_trait>" }
Abilities = { { Id = "<existing_subtree>", Params = <typed_params> } }
Attack = <typed_existing_attack_params>
```

Proposed ordinary base XP = 0.2 * baseHP; the seven source droids yield 20/20/10/20/60/30/24 XP. Proposed linear progression is 100 total XP per level, Level = 1 + floor(TotalXP / 100). These candidates await playtests.

E's v0.1 BossDefinition references the canonical Regular droid/template/brain/attack, overrides HP to 5000 (times 50), and supplies a larger uniform scale (2 proposed). Its explicit base-XP override is proposed as 100. No extra phases/abilities or player-count HP scaling. Boss contribution-shared rewards are selected by boss/event policy; non-boss deaths keep KillerOnly. Use the actual exported BossDefinition shape after freeze rather than adding unreviewed fields to this schematic DroidDefinition.

Use the canonical strategy schema; do not insert arbitrary functions or `any` dictionaries to bypass validation. Server-only hooks stay behind registered IDs. Freeze definitions through the registry. Asset references must satisfy [MODEL_CONTRACT](../../MODEL_CONTRACT.md).

Before enabling: no unresolved placeholders/TODO tuning masquerading as final balance, no duplicate IDs, all references valid, exact source numbers preserved for existing content, and relevant acceptance tests/evidence recorded.
