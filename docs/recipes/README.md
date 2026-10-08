# Content extension recipes

These ten checklists and separate Markdown template files are **planning artifacts**. Their field names are proposed; use the actual exported Contracts v1 types after freeze. Templates are schematic and contain unresolved angle-bracket placeholders; they are not executable Luau and must not be copied into production unchanged.

Current v0.1 scope follows the owner's clarifications in [DECISIONS](../DECISIONS.md): 240-second rounds and boss deadlines; non-boss KillerOnly versus boss contribution sharing; persisted free-spin connected-playtime; Tornado only; larger Regular bosses at HP times 50; no agent-owned chair/sofa/obby or gem systems. Linear XP pacing, speed nerf, Tornado repetition, exact boss scale and active-wheel normalization are proposals with later verification tasks. Recipes for future content do not authorize that content now.

| Recipe | Template | Owner |
|---|---|---|
| [Gear](ADD_GEAR.md) | [GearDefinition](templates/GEAR.md) | C |
| [Utility](ADD_UTILITY.md) | [UtilityDefinition](templates/UTILITY.md) | F |
| [Armour](ADD_ARMOUR.md) | [ArmourDefinition](templates/ARMOUR.md) | F |
| [Class](ADD_CLASS.md) | [ClassDefinition](templates/CLASS.md) | F |
| [Droid](ADD_DROID.md) | [DroidDefinition](templates/DROID.md) | D |
| [Map](ADD_MAP.md) | [MapDefinition](templates/MAP.md) | A |
| [Event / Disaster](ADD_EVENT.md) | [EventDefinition](templates/EVENT.md) | E |
| [Scenario](ADD_SCENARIO.md) | [ScenarioDefinition](templates/SCENARIO.md) | A |
| [NPC Dialogue](ADD_NPC_DIALOGUE.md) | [DialogueGraph](templates/NPC_DIALOGUE.md) | H |
| [Product](ADD_PRODUCT.md) | [ProductDefinition](templates/PRODUCT.md) | G |

## Shared process

1. Reserve the domain file and asset path with its owner.
2. Use a registered strategy/handler/subtree and the frozen typed schema.
3. Fill approved values and valid references, add the definition file, and let the registry discover it.
4. Validate config/assets and run domain tests plus format/lint/type/build checks.
5. Demonstrate automatically generated shop/loadout/UI/pools where applicable, then cleanup.
6. Record evidence and ADRs; do not commit/push without approval.

A new mechanic needs a separately owned behavior implementation; it cannot be demonstrated by claiming a data-only extension. Changing a frozen schema or adding a dependency requires the contract/ADR approval workflow. Source economy changes require owner approval.

## Required one-file extension proof and droid-pool caveat

Gear, map, class and event discovery can consume a new definition directly through existing registry-generated lists. Droid selection uses explicit Map.DroidPool references in the source, so a new droid ID will not automatically become map-eligible. R-20 proposes optional **EligibleMapIds on the new DroidDefinition**, unioned with each map's explicit pool. Review and record this before freeze, validate map IDs, deduplicate, and keep event-only droids out. Preserve the three original eligible pools exactly for original definitions. Merely adding an unused droid definition is not a successful gameplay extension proof, and silently editing a map alongside it does not meet the one-file claim.

See [decision register](../DECISIONS.md), [catalog](../CONTENT-CATALOG.md), [asset contract](../MODEL_CONTRACT.md) and [verification](../TEST-PLAN.md).
