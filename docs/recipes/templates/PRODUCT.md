# ProductDefinition — schematic template

Related recipe: [Add Product](../ADD_PRODUCT.md).

This is a **non-executable planning template**. Angle-bracket fields must be replaced with owner-approved values and actual Contracts v1 field names. The final definition must be a strict Luau ModuleScript returning typed, validated data. No price/damage/time placeholder below is adopted balance. Optional fields should be omitted when the selected strategy does not use them.

```text
Id = "<new_product_id>"
ProductId = 0 -- unset; owner supplies real ID later
ProductKind = "DeveloperProduct" | "Gamepass"
PriceRobux = <owner_approved_price>
GrantKind = "<existing_handler_id>"
Params = <typed_handler_params>
```

No gem GrantKind or params are allowed in active v0.1 products (D-18). A paid-spin handler grants durable pending spin credit and does not advance/reset `FreeSpinRemainingSeconds`, the proposed profile field holding the free countdown (D-13). That timer advances only while connected and pauses offline, including across profile release/reload. Chair/sofa/obby products are outside agent scope (D-17).

Use the canonical strategy schema; do not insert arbitrary functions or `any` dictionaries to bypass validation. Server-only hooks stay behind registered IDs. Freeze definitions through the registry. Asset references must satisfy [MODEL_CONTRACT](../../MODEL_CONTRACT.md).

Before enabling: no unresolved placeholders/TODO tuning masquerading as final balance, no duplicate IDs, all references valid, exact source numbers preserved for existing content, and relevant acceptance tests/evidence recorded.
