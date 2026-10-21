# Libation Warriors — gameplay and implementation contract
October 15, 2026. Source of truth for the newly discussed design, not a claim that every feature is playable.

## Identity and acquisition (locked)
- A normalized UPC/EAN maps to **one immutable, globally consistent base warrior blueprint**. A player's same UPC may be acquired only once; re-scanning does not mint a second warrior. Progression is individual.
- Spirits and other verified alcoholic beverages map to the established factions. **All nonalcoholic beverages map to Nimrod.** Unknown catalog products must not silently acquire a faction.
- Real acquisition is allowed **only at one profile-designated private fixed location**, not a business or restaurant. Players may change this designated location only once every **30 days**. The exact coordinate/address is never published to other players.
- On each acquisition, the server generates a fresh unpredictable, expiring, single-use challenge. The player handwrites the challenge on real paper; the app captures **the actual product and handwritten challenge together** using a live camera. Validate readable handwritten code, matching bottle/product and barcode, freshness, device integrity, geo evidence, and indications of rephotographed/printed/screen-displayed/altered imagery.
- A still photograph, OCR, GPS and anti-spoofing classifiers **cannot prove ownership or perfect liveness**. Use layered live motion challenge, risk review and appeal. Verification must fail closed in public builds; developer demo acquisition is explicitly unverified and must not be counted as production ownership.
- No proof by purchasing, drinking, or photographing liquid in a glass is required. Do not share private addresses, receipts, photos or raw position in public profiles.
- Exact geofence radius, registration method, privacy policy, age validation, camera plugin, ML provider, replay detection and trusted verification service require production implementation and testing.

## World map and entrances
- Live map of bars, taverns, and alcohol-serving restaurants: **Spacetime Ruptures**. Entrance transforms the establishment into an alternate-reality roguelike dungeon.
- Distilleries, wineries, meaderies, breweries and similar producers: **Wormholes**. Entrance opens a more chaotic challenge dungeon with more powerful foes.
- A place on the world map is a fantasy-game anchor, NOT permission to enter physical private property. Allow safe remote party participation as compatible with location-access rules; no driving/drinking incentives.
- Each location has at most five active Corrupted Paths.

## Cooperative dungeons
- Accepting an entrance opens a lobby for **1–4 players**, with a two-minute join timer and selection of **one warrior per player**.
- When every currently joined player marks ready, start a **10-second launch countdown**, including solo players. A separate ten-minute solo wait would be a design inconsistency; the playable solo prototype uses ten seconds.
- More players mean stronger/more complex encounters; party size max four. Dungeons are roguelike with changing layouts and drops. Gold is in-game currency.
- Five **successful** completions per location per day are free; additional successes cost gold. Failures do not use free completions. A failed run loses a defined percentage of **run-acquired** gold/items; tune percentages later.
- Modifiers for ruptures and wormholes can be purchased with earned gold. All charges, rewards, counters and match outcomes require server validation.

## Corrupted Paths
- After normal/challenge dungeon success, rank participants by **items collected, damage dealt, damage taken, items used**. Design score should also reward support roles and cooperative objectives before launch.
- Highest-scoring eligible player has first refusal to leave an immutable snapshot of the warrior they used as a shadow boss; if they decline or cannot place, offer to the next ranked player.
- Per player: max five concurrent paths. Per location: max five. Path difficulty uses shadow level + permitted modifiers and scales fairly with party size.
- Successfully clearing the Corrupted Path closes it; the high scorer gets an opportunity to replace it by the same rules.
- Each open path earns capped gold as time passes. Daily earnings are awarded **at the start of the next day**, even if still open, and subject to a shared account daily cap and weekly cap. Path closure stops future accrual.
- Weekly bonus at the next week boundary uses highest eligible open-duration bracket: **12h, 24h, 48h, 56h, 168h**. Brackets are non-stacking unless explicitly revised. Decide whether closed paths that reached a threshold still qualify; never invent reward amounts.
- Economy calculations, unique event processing, rollover and UTC clock are server-owned; mobile values are display-only.

## Fusion
- Multiple max-level warriors can form a fusion. Fusion inputs, level cap, requirements, inheritance rules, ownership and permanence remain to be defined. One active warrior enters a dungeon.

## Implementation status at this milestone
**Existing and partly playable:** deterministic blueprints, scanner plugin foundation, faction generation, collection, single-warrior procedural dungeon combat, Supabase auth/cloud-save foundation, Android debug export.
**Added here:** deterministic lobby/path rules, solo READY -> ten-second countdown, clearer distinction between dev-only unverified scans and production scans; tests and CI validation.
**Not built yet:** validated designated-location enrollment and 30-day changes, handwritten-photo anti-spoofing + trusted backend, age gate, approved place-data map, online four-player match service, shared path state, gold economy, fusion art/mechanics, public release security review.

## Engineering constraints
- Work only on existing `cursor/pirate-master-poses-0762` branch and preserve useful art/code.
- Never ship a Supabase service-role key in Android; RLS is necessary but **not sufficient** to validate user-generated photos, coordinates, scores or rewards.
- Prior foundational migration currently allows client-side blueprint insertion. Production release requires a migration to revoke direct acquisition and move it behind a trusted server function with anti-fraud checks, without breaking debug test data.
- Production verifier cannot be substituted by a fake/mock provider that always accepts.
- APK artifact demonstrates installability/buildability only, not working server-backed acquisition, live multiplayer, or fraud resistance.
