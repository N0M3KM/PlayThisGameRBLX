# DialogueGraph — schematic template

Related recipe: [Add NPC Dialogue](../ADD_NPC_DIALOGUE.md).

This is a **non-executable planning template**. Angle-bracket fields must be replaced with owner-approved values and actual Contracts v1 field names. The final definition must be a strict Luau ModuleScript returning typed, validated data. No price/damage/time placeholder below is adopted balance. Optional fields should be omitted when the selected strategy does not use them.

```text
NpcId = "<new_npc_id>"
EntryNodeId = "entry"
Nodes = {
  entry = {
    Text = "TODO(owner)",
    Choices = {
      { Id = "leave", Kind = "Leave", Text = "TODO(owner)" },
      -- Add owner-authored Chat/Quest/CompleteQuest/Secret choices.
      -- NextNodeId, ConditionId and ActionId reference existing registered values.
    },
  },
}
```

Use the canonical strategy schema; do not insert arbitrary functions or `any` dictionaries to bypass validation. Server-only hooks stay behind registered IDs. Freeze definitions through the registry. Asset references must satisfy [MODEL_CONTRACT](../../MODEL_CONTRACT.md).

Before enabling: no unresolved placeholders/TODO tuning masquerading as final balance, no duplicate IDs, all references valid, exact source numbers preserved for existing content, and relevant acceptance tests/evidence recorded.
