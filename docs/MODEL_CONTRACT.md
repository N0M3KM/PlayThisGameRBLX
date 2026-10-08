# Draft asset contract

Status: proposed for Phase 0 review/validation, **not frozen**. The owner authors final assets. v0.1 may create unstyled primitive Parts/rigs and bare Frames only. Requirements become Contracts v1 when validator fixtures, Rojo mapping and Studio smoke tests pass. Changing them afterward requires a CCR.

## Ownership and mapping

| Authored source | Intended runtime destination | Owner |
|---|---|---|
| `assets/Maps/<MapId>.rbxm` or Rojo model directory | `ServerStorage/Assets/Maps/<MapId>` | A |
| `assets/Droids/<DroidId>` | `ServerStorage/Assets/Droids/<DroidId>` | D |
| `assets/Droids/Bosses/<BossId>` | `ServerStorage/Assets/Bosses/<BossId>` | E |
| `assets/Gear/<GearId>` | `ServerStorage/Assets/Gear/<GearId>` | C |
| `assets/Utilities/<UtilityId>` | `ServerStorage/Assets/Utilities/<UtilityId>` | F |
| `assets/NPCs/<NpcId>` | server template; visible lobby clone | H |
| `assets/Lobby/{Match,Commerce}` | persistent `Workspace/Lobby` subtree | A/G |
| `src/client/UI` authored templates | `StarterGui/PTG` or approved Rojo UI mapping | I |

Exact file format/mapping is a Phase 0 decision. Do not maintain two authored copies of one subtree. Public cosmetic templates may be mapped into a separate replicated folder only when required; no server code/private data goes there.

## Map template

```text
<MapId> (Model, Attribute MapId:string)
  Geometry (Folder)
  PlayerSpawns (Folder, at least 1 anchored BasePart)
    <SpawnId> (BasePart, tag PlayerSpawn, Attribute SpawnId:string)
  DroidSpawns (Folder, at least 2 anchored BaseParts)
    <SpawnId> (BasePart, tag DroidSpawn, Attribute SpawnId:string)
  Bounds (Folder)
    RecoveryPoint (anchored BasePart)
  Destructibles (Folder, optional)
```

Spawn Parts are primitive markers without decorative design, non-collidable and non-queryable except where the validator needs them. Position/direction is represented by CFrame. Spawn IDs are unique within the map. RecoveryPoint must be above configurable RecoveryHeight; engine FallenPartsDestroyHeight is lower. Map pivot/bounds are finite; no running Scripts or unmanaged remotes inside owner assets. At least two DroidSpawns permit respawn excluding the previous point. Validate minimum-player-distance policy separately; when no point meets distance, bounded retry/fallback follows a documented decision.

`MapDefinition.Template` resolves this model; `DroidPool` IDs must exist. Tag only eligible breakable BaseParts/Models `Destructible`. Optional metadata: `DestructibleId:string`, `DebrisLifetimeSeconds:number` overriding a config default only under approved schema, `Health:number`. Collision groups and caps are system-owned. Never tag spawns/bounds or core lobby structures destructible.

## Droid and boss rig

```text
<DroidId> (Model; Attributes DefinitionId:string, Faction:string)
  HumanoidRootPart (BasePart, model PrimaryPart)
    RootAttachment (Attachment)
  Humanoid (Humanoid)
    Animator (Animator)
  <rig parts and joints>
```

Require a connected unanchored assembly, valid root/positive humanoid health, and rig metadata compatible with its adapter. Rig adapter explicitly supports R6/R15 where used; never require R15 limb names universally. Animations are optional placeholders, with named markers defined by ability contracts before they affect gameplay. Attachments for ranged origin use `MuzzleAttachment` on the configured rig part. Missing ranged origin is an actionable failure. Server sets network ownership and collision groups after spawn, and sets scoped RuntimeEntityId/RoundId attributes; templates must not carry stale runtime IDs.

The v0.1 boss follows this rig contract by reusing the Regular Droid rig and its existing brain/attack/abilities (D-16). The BossDefinition changes HP to 50 times Regular HP (5000 at Regular HP 100) and body size; uniform scale 2 is proposed pending Studio clearance tests. Do not require boss-specific phases, ability attachments, new attacks or player-count HP scaling. E references D's canonical Regular template and clones/scales it rather than maintaining a second authored rig. The bosses source directory may contain metadata or an owner asset reference later; a separate rig is not required for v0.1. Reward XP is a separate explicit definition value, not derived from the scaled HP.

Scaled clones retain the same attachment names and adapter compatibility. Derive/test path agent radius/height, spawn clearance, assembly collisions, attack origins/reach and recovery against the scaled body; scaling cannot bypass map validation. Pool reset must clear boss IDs and restore the Regular scale/HP before ordinary reuse, or use an explicitly separate boss pool. Two required bosses instantiate the same definition with distinct runtime IDs and independently tracked HP/lifecycle.

## Gear and utilities

Gear template: Tool named by GearId, Attribute `DefinitionId:string`; use `RequiresHandle=false` for a primitive handleless placeholder or provide a BasePart `Handle`. Gun tools require `MuzzleAttachment` at the documented origin. Melee origin/hitbox attachments are validated against BehaviorId. Tools cannot contain independent damage/purchase logic or scripts granting client authority; GearService owns behavior and grant/removal.

Deployable utility templates are Models with a PrimaryPart, `DefinitionId`, and the required placement/root attachment for their registered behavior. Turret uses a server-owned targetable root, MuzzleAttachment and configured 1000 HP. Landmine uses a server-owned anchored trigger/query volume. Runtime faction/owner/round IDs are assigned by the server, not taken from template/user requests. Bloxy Cola/Ammo Box can be bare tool primitives.

Armour/class strategies can use stat-only placeholders. Ghost transparency must restore on character cleanup. Follower turret uses the turret/ally targeting contracts, not hidden scripts in an accessory. No final accessory/model design is required.

## Lobby and NPC primitives

Lobby contains safe spawn markers; three voting pad BaseParts with `VotePad` tag and `PadIndex` 1–3; AFK query Part tagged `AFKZone`; primitive commerce/NPC interaction volumes. Pad map choices are runtime IDs assigned by VotingService. Zone geometry is server-queryable and collision policy is explicit.

NPCs are primitive Models with a root and `NpcId` matching the dialogue registry. Interaction distance is configured and checked server-side. Graph files contain owner TODO text for Helper Robot, NomeKM the evil dev, Mrs.Rin and Somchai. Do not author conversations.

Chair/sofa commerce and the obby are outside agent scope (owner-confirmed D-17). No asset templates, interaction volumes, costs or reward hooks for them are required; leave their design and implementation to the owner. Required match/commerce/NPC assets must function without them.

UI shells use named ScreenGui/Frame/TextLabel/TextButton objects, unstyled and inspectable. They bind replicas/signals and input actions. Show required dialogue state colors only as functional semantics specified in the brief; do not add a theme.

Do not add gem counters, gem prizes, gem shop surfaces or related UI fields (D-18). The wheel's free timer displays the replicated remaining connected-playtime and readiness, not a wall-clock deadline; render only cosmetic local interpolation and reconcile to server state.

## Validator and acceptance fixtures

- Reject missing/wrong classes, duplicate/unknown IDs, absent attachments/root, unsafe spawn/recovery positions, invalid tagged ancestry and running unauthorized scripts.
- Error messages include asset path, field, expected type/value and suggested correction; fail early in Studio and build/config checks where possible.
- Positive fixtures: three primitive maps, all seven droids, gun/melee/deployable tools, a boss clone reusing the Regular rig at validated scale, four NPC primitives. Validate one- and two-boss placement/clearance without adding a second authored boss rig.
- Negative fixtures: one droid spawn, missing PlayerSpawns, unknown DroidPool, stale runtime IDs, absent MuzzleAttachment, invalid Humanoid/root, unsafe destructibles.
- Studio test clone → validate → spawn/teleport → cleanup; persistent lobby/pools remain at baseline. Format/lint/type checks accompany validator implementation.
