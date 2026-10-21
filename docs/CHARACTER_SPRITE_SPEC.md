# Character Sprite / Animation Specification

This is the production contract for generated Libation Warriors. It is intentionally stricter than the legacy sprite importer.

## Goals

Every generated warrior must support visual variety and synchronized combat animation without floating weapons or detached layer motion.

## Canonical production frame

Preferred new production cell: **64 × 64 px** for the current Pirate/Brine pipeline.

Some legacy faction sheets are 64 × 80. Keep those behind their existing adapter until they are re-authored; do not silently crop or stretch them into this contract.

- nearest-neighbor filtering
- no mipmaps
- same canvas dimensions for every frame in one character set
- transparent background
- stable feet/contact baseline
- integer-friendly display scaling

## Directions

Every production animation set must expose four gameplay directions:

- DOWN
- LEFT
- RIGHT
- UP

Mirroring LEFT/RIGHT is acceptable when anatomy, weapon hand, accessories, and silhouette remain logically correct. UP and DOWN require authored directional poses; rotating a side-facing sprite does not count.

## Required state names

At minimum:

- \`idle_<direction>\`
- \`walk_<direction>\`
- \`attack_<direction>\`
- \`special_attack_<direction>\`
- \`hit_<direction>\`
- \`defeated_<direction>\`

Future-compatible states:

- \`block_<direction>\`
- \`dodge_<direction>\`
- \`cast_<direction>\`
- \`interact_<direction>\`

## Frame targets

- Idle: 4+ meaningful frames
- Walk: 6+ meaningful frames per direction where practical
- Regular attack: 6–10+ meaningful frames per direction
- Special: enough frames to clearly communicate the action
- Hit: 3+ meaningful frames
- Defeated: 5+ meaningful frames where appropriate

Repeated copies of the same still frame are not animation.

## Attack phase contract

A melee attack must visibly progress:

1. prepare
2. reach/draw weapon
3. wind-up
4. active swing
5. contact
6. follow-through
7. recovery
8. return to idle/move

Frame metadata must identify one or more active frames. The damage hitbox is disabled during wind-up, enabled only for active/contact frames, and disabled during follow-through/recovery.

One swing has one hit ledger; an overlapping target cannot receive accidental repeated damage from the same attack instance.

## Layered generated warriors

The target generated renderer uses synchronized layers such as:

- body
- legs
- shirt
- coat
- head
- hair
- headwear
- weapon
- off-hand
- accessory

All layers share exactly the same:

- state
- direction
- frame index
- canvas dimensions
- root pivot
- body anchor
- hand/weapon anchors
- playback timing

Barcode generation chooses component IDs in \`AppearanceData\`. It does not independently animate layers.

## Anchors

For 64×64 art, use a common root centered on the cell and a consistent foot baseline near the lower portion of the canvas. Exact per-frame weapon/hand anchor data should be stored alongside animation metadata, never guessed by UI code.

Recommended metadata structure:

\`\`\`gdscript
{
  "frame": 4,
  "body_anchor": Vector2(...),
  "weapon_hand_anchor": Vector2(...),
  "offhand_anchor": Vector2(...),
  "hitbox": Rect2(...),
  "active": true
}
\`\`\`

## Collision and hitboxes

The movement collision body stays stable through an attack unless a deliberate lunge mechanic moves the CharacterBody2D.

Attack hitboxes are directional and derived from facing:

- RIGHT → positive X
- LEFT → negative X
- DOWN → positive Y
- UP → negative Y

Visual weapon reach and collision reach must agree.

## Existing Pirate status

The repository already contains a real multi-frame Pirate attack pipeline and six right-facing master pose assets. Those assets are useful and should be preserved.

They are **not yet a complete four-direction set**. The next art/combat pass should author UP and DOWN sequences from the approved Pirate design while retaining the existing right/left work.
