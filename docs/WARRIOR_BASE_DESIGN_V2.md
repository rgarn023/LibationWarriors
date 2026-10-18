# Deterministic Warrior Base Art — v2
- All normalized UPCs resolve to one immutable original base blueprint. A player's scanned UPC cannot mint a duplicate.
- **Gender is deterministic per UPC** and is stored in both blueprint serialization and progression restore; never randomized per account or device.
- 16 existing faction archetypes have distinct headgear, equipment, silhouette and colors. New runtime 64×80 original pixel-art **collection/summon portrait** via `WarriorBaseArt`; visual features including gender, face, hair, skin, silhouette and archetype are part of the global identity signature.
- `AppearanceData.assign_to` uses only the original barcode-seeded RNG; the addition of gender does not alter the seed or category resolution.
- Existing persisted global blueprints are immutable. Do not overwrite previously claimed base blueprints during a migration. Old saved blueprints that lack gender render with a deterministic seed-derived fallback.
- This iteration redesigns the **static portrait bases**, not the legacy combat sheets. Full synchronized, male/female, multi-direction attack sprites must be authored and integrated separately without falsely representing side-facing art as four-direction animation.
- Existing or new local/offline demo acquisitions are unverified and should not automatically migrate into a verified production account.
