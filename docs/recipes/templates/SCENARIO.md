# ScenarioDefinition — schematic template

Related recipe: [Add Scenario](../ADD_SCENARIO.md).

This is a **non-executable planning template**. Angle-bracket fields must be replaced with owner-approved values and actual Contracts v1 field names. The final definition must be a strict Luau ModuleScript returning typed, validated data. No price/damage/time placeholder below is adopted balance. Optional fields should be omitted when the selected strategy does not use them.

```text
Id = "<new_scenario_id>"
DisplayName = "<owner_name>"
Weight = <positive_relative_weight>
DroidMultiplier = <approved_multiplier>
RewardMultiplier = <approved_multiplier>
EventCount = { Min = <approved_min>, Max = <approved_max> }
DisasterCount = { Min = <approved_min>, Max = <approved_max> }
BossCount = <approved_count>
```

All v0.1 scenarios use global round duration 240 seconds; boss deadline is also 240 seconds (D-01/D-02). Do not add per-scenario conflicting timer fields. Source one/two-boss counts remain unchanged. D-16's proposed Tornado-repeat policy fills multi-event/disaster slots with distinct scoped occurrences of the single implemented definition and one aggregate budget; category/slot compatibility must be validated before freeze. Bosses reuse Regular behavior with HP times 50 and larger size, not new phases or player-count HP scaling.

Use the canonical strategy schema; do not insert arbitrary functions or `any` dictionaries to bypass validation. Server-only hooks stay behind registered IDs. Freeze definitions through the registry. Asset references must satisfy [MODEL_CONTRACT](../../MODEL_CONTRACT.md).

Before enabling: no unresolved placeholders/TODO tuning masquerading as final balance, no duplicate IDs, all references valid, exact source numbers preserved for existing content, and relevant acceptance tests/evidence recorded.
