# Libation Warriors

Android-first Godot action RPG/collector where scanning a real beverage barcode reveals a deterministic warrior.

> **Development branch:** \`cursor/pirate-master-poses-0762\`  
> **Godot:** 4.7.x project (developed against 4.7.1)  
> **Android package:** \`com.libationwarriors.game\`

## Current foundation

The September 28, 2026 foundation pass preserves the existing scanner, collection, dungeon renderer, Android plugin, safe-area code, and Pirate animation work while adding:

- 5-second CG splash framework using the original logo frames
- Supabase email/password auth + persistent refresh session
- versioned relational schema/RLS migration
- local + cloud save synchronization foundation
- canonical UPC/EAN → SHA-256 → deterministic seed identity
- global immutable warrior blueprint + per-user progression model
- database and client duplicate protection
- modular product lookup with no random unknown-faction fallback
- deterministic Pirate appearance-component signature
- extensible attack/equipment override fields
- responsive original bar/tavern Main Hub
- primary routes: SCAN / COLLECTION / EXPLORE / BATTLE
- Explore difficulty selection
- seeded 10–25 room connected dungeon generation
- centralized encounter-budget scaling
- versioned Android export destination under \`build/\`
- deterministic foundation test scene

## Important setup

The original Charoite Games GIF was not present during this handoff and is **not regenerated**. Re-upload it and follow \`assets/branding/README.md\`.

Supabase client setup is documented in \`docs/SUPABASE_SETUP.md\`. Never commit a service-role/secret key.

## Architecture

See:

- \`docs/ARCHITECTURE.md\`
- \`docs/CHARACTER_SPRITE_SPEC.md\`
- \`docs/CHARACTER_ANIMATION_SETUP.md\`

## Tests

Run:

\`scenes/tests/foundation_tests.tscn\`

The test scene validates deterministic barcode identity and repeated dungeon generation/reachability.

## Build output

The Android preset targets:

\`build/LibationWarriors-v001-debug.apk\`

A filename in the export preset is **not** proof that an APK has been built. Report an APK only after an actual export succeeds and the file size/SHA-256 are measured.

## Known unfinished milestone items

- original CG splash frames must be supplied
- Supabase migration must be applied to the confirmed project
- true authored UP/DOWN Pirate attack animation is still required
- true authored UP/DOWN Pirate attack animation is still required
- enemy attack/HIT/DEFEATED states still need genuine authored multi-frame art
- emulator and physical Galaxy QA have not yet been performed for this foundation pass
