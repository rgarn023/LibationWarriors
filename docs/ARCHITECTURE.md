# Libation Warriors Architecture

Status date: September 28, 2026  
Active development branch: \`cursor/pirate-master-poses-0762\`

## Product principle

A real-world retail barcode reveals a permanent base warrior identity. The base identity is deterministic and global; player-owned progression is separate.

\`\`\`
scan
→ canonicalize UPC/EAN
→ SHA-256 barcode identity
→ product/category resolution
→ faction
→ deterministic base blueprint
→ idempotent ownership
→ player-specific progression
\`\`\`

Unknown product/category data does not fall back to a random faction.

## Startup

\`scenes/startup.tscn\` is the project main scene.

1. Black Charoite Games splash surface.
2. Original CG frames play at approximately 12.5 FPS and loop only as needed until five seconds total.
3. Restore the Supabase refresh-token session.
4. Pull cloud state.
5. Merge local/cloud state without discarding higher local level/XP.
6. Enter the Main Bar, or route to Auth if no valid session exists.

The original CG GIF is intentionally not regenerated. It must be re-uploaded and losslessly extracted to \`assets/branding/cg_splash_frames/\`.

## Authentication

\`SupabaseClient\` provides:

- email/password sign-up
- email/password sign-in
- refresh-token session restore
- logout
- password-reset email request
- authenticated PostgREST requests

Client configuration comes from environment variables or \`config/supabase.public.json\`. Only a Supabase publishable key (or legacy anon key during migration) belongs in the client. Never ship a service-role or secret key.

The session currently uses a \`user://\` JSON cache. Before production release, Android Keystore-backed token-at-rest storage should replace this basic cache.

## Database and RLS

Migration: \`supabase/migrations/20260928155100_foundation.sql\`.

### profiles

Per-user player state and lightweight settings. RLS allows only \`auth.uid() = user_id\`.

### warrior_blueprints

Global immutable base identity keyed by the 64-character SHA-256 barcode hash.

Clients can read blueprint fields and insert a previously unseen blueprint. They cannot update or delete a blueprint. The insert policy verifies that the submitted hash equals the SHA-256 of the submitted normalized barcode.

The raw normalized barcode column is not granted for normal authenticated SELECT. Player-owned rows keep their own barcode value for restore.

A future production hardening step should move first-claim blueprint creation/product verification into an Edge Function or other trusted server path so a malicious modified client cannot be the first writer for a new barcode.

### user_warriors

Per-user ownership/progression with a composite primary key \`(user_id, blueprint_id)\`. This makes acquisition idempotent at the database layer. A trigger verifies that the owned barcode hashes to the linked global blueprint.

Progression columns include level, XP, equipment, regular/special attack overrides, and extensible progression JSON.

## Barcode identity

\`BarcodeIdentity\` is the only canonical identity module.

Supported retail lengths are 8, 12, and 13 digits. EAN-13 values beginning with zero collapse to their UPC-A identity. UPC-E expansion is supported when scanner symbology identifies it as UPC-E; an arbitrary 8-digit value is otherwise preserved because EAN-8 and UPC-E cannot be safely distinguished from digits alone.

Identity:

\`\`\`
canonical barcode
→ SHA-256 lowercase hex
→ first 60 hash bits as deterministic positive seed
\`\`\`

Synthetic internal IDs beginning with \`DUN-\`, \`LOCAL-\`, \`DEMO-\`, \`EVENT-\`, or \`LW-\` are supported for game/debug generation but are not treated as retail barcodes.

## Product resolution

\`ProductResolver\` owns external metadata lookup. The current provider adapter uses Open Food Facts and returns only category/faction-relevant information to gameplay.

\`WarriorFactory.classify_product_dict()\` classifies product metadata. If the resolver cannot establish a supported beverage category, summoning stops instead of assigning a random faction.

The interface is intentionally isolated so another UPC/product service can replace or supplement Open Food Facts later.

## Factions and warrior generation

\`FactionData\` owns category → faction mapping and move pools. Rum maps to Pirate.

\`WarriorFactory\` uses the barcode-derived seed to deterministically generate:

- name
- faction
- fallback palette
- base stats
- regular attack
- special attack
- appearance components
- appearance signature

Product imagery is no longer allowed to alter the base warrior, because mutable imagery would violate deterministic global identity.

\`AppearanceData\` contains component pools. Pirate has dedicated body/head/hair/facial-hair/headwear/shirt/coat/pants/boots/belt/weapon/off-hand/accessory/palette pools. These IDs are the contract for future synchronized sprite layers.

Example signature:

\`accessory=scar_01|belt=sash_02|body=body_03|coat=coat_04|...|weapon=cutlass_02\`

## Attack and item extensibility

A \`Warrior\` stores immutable original move names/base power plus:

- \`equipment\`
- \`regular_attack_override\`
- \`special_attack_override\`
- \`progression\`

\`regular_attack_data()\` and \`special_attack_data()\` merge overrides onto the base move. This lets future items replace attacks, change power, or add effect metadata without rewriting the barcode blueprint.

## Main Bar

The Main Bar is a responsive original tavern scene. Primary routes are only:

- SCAN
- COLLECTION
- EXPLORE
- BATTLE

Legacy Party/Event scenes are preserved in the repository but are no longer primary home buttons.

## Scanner

Android scanning still uses the existing \`UpcScanner\` Godot Android plugin.

The scanner now:

- canonicalizes before lookup
- accepts supported UPC/EAN identity
- rejects unknown/unclassifiable products
- blocks duplicate local ownership
- uses a processing lock and 1.5-second callback debounce
- relies on database uniqueness as a second duplicate barrier
- shows “Warrior Already Discovered” for owned identities

The current Android bridge emits barcode digits but not scanner symbology. To distinguish UPC-E from EAN-8 perfectly, a future plugin revision should emit both value and format.

## Collection

Collection retains the existing mobile list/detail UI and no longer displays the raw barcode. It shows a shortened hash-based Warrior ID, appearance signature, combat stats, attacks, and equipment slot count.

A card/grid redesign remains a UI polish task.

## Explore and dungeon generation

\`DungeonBalanceConfig\` centralizes difficulty, length, encounter budget, enemy count, and enemy level.

\`DungeonGenerator\` separates the logical connected graph from \`dungeon_explore.gd\` rendering.

Properties:

- 10–25 rooms inclusive
- length scales with warrior level and Easy/Normal/Hard
- deterministic run seed
- unique grid coordinates
- connected growth from entrance
- boss/exit selected at maximum BFS depth
- key room distinct from entrance/exit
- per-room depth and encounter budget
- enemy count derived from budget, not random ad-hoc duplication

\`dungeon_explore.gd\` consumes \`enemy_count\` and fixed spawn slots so a saved/replayed dungeon is reproducible.

## Combat state

The current real-time dungeon already prevents attack restart while attacking and resolves the player hit on authored attack-frame indices rather than at button press. Hit direction uses cardinal UP/DOWN/LEFT/RIGHT.

However, the current Pirate authored animation asset is still side-facing and horizontally mirrored. True authored UP and DOWN body/weapon attack sequences, plus complete HIT/DEFEATED player state integration, remain required before the “full directional combat demonstration” milestone can be called complete.

Do not substitute a static character plus a floating slash for that work.

## Character animation contract

See \`docs/CHARACTER_SPRITE_SPEC.md\`.

## Mobile

The project remains portrait-first at 720×1280 logical resolution with \`canvas_items\` + \`expand\`, safe-area handling, nearest texture filtering, and Android camera/network permissions.

Current dungeon movement uses touch directional buttons. Replacing that D-pad with a true analog virtual joystick while preserving multi-touch attack/special input is still pending.

## Android export

The Android export preset now points to:

\`build/LibationWarriors-v001-debug.apk\`

Package: \`com.libationwarriors.game\`

The repo change does not prove a successful APK build. A build must be produced and hashed before reporting it as successful.

## Tests

\`scenes/tests/foundation_tests.tscn\` covers:

- UPC/EAN normalization aliasing
- stable SHA-256/hash seed
- same barcode/category → same blueprint/faction/attacks/appearance
- dungeon room count 10–25 across levels/difficulties/seeds
- entrance/exit validity
- full graph reachability
- unique room coordinates
- same seed → same room graph
- cardinal direction math

Database uniqueness/RLS should also be tested against the actual Supabase project after the migration is deployed.

## Remaining milestone work

The highest-priority unfinished work is:

1. add the original CG GIF frames
2. configure/confirm the correct Supabase project and apply the migration
3. author true UP/DOWN Pirate attack sequences and finish HIT/DEFEATED state wiring for player + enemy
4. replace dungeon D-pad with a safe-area-aware analog joystick
5. run Godot tests, Android emulator QA, and physical Galaxy QA
6. build and checksum the versioned debug APK
