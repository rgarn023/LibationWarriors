# Libation Warriors — GPS Overworld Build Contract (v14)

## Product identity
Build a **local GPS-driven role-playing overworld**, not a zoomable road atlas.
The surrounding world must be drawn from **real geographic data**, with original
illustrated 16-bit terrain and a visually polished player avatar. The behavior
should feel like a Pokémon GO-style GPS exploration camera, while its **art is an
original SNES-era action-RPG aesthetic** informed by the user's approved reference.

## Ground truth, loading and honesty
- The phone's **actual HTML5 geolocation** supplies player coordinates. Require
  secure HTTPS and user permission; never assume the user's city or exact address.
- Use OpenStreetMap/OpenFreeMap **geometry as the sole geographic source** for
  coastlines, water, streets, public paths, parks and buildings.
- Do **not** show the static concept illustration under a UI that says LIVE WORLD.
  Until both GPS and geographic features are ready, show an explicit loading/error
  state, not a fictional place masquerading as a real one.
- Geographic features are drawn in local/relative coordinates and updated when
  tiles change. Attributions and source limitations must remain accessible.
- A diagnostic displays whether GPS, geographic drawing and venue data are ready.
  Real-time failures cannot silently switch to invented venue positions.

## View and movement
- Fixed local-area gameplay scale; do not offer full-world browsing or free
  zoom to any city. Keep a comfortable surrounding radius.
- The **custom avatar is a georeferenced world entity**, not a portrait fixed to
  screen coordinates.
- Smooth GPS jitter, animate between valid fixes, and never fake walking by
  dragging the map. Standing still means idle animation.
- Follow camera keeps the avatar low-center so the player can see ahead;
  swipe to orbit the viewpoint. Recenter resumes follow.
- Render shapes/markers and avatar through a consistent coordinate transform,
  avoiding screen-space offsets that produce displaced portals.

## Visual target
- Original fantasy pixel artwork: tiered tree crowns, lively grassy ground,
  sandy paths, friendly village roofs, clear blue shoreline and water.
- **No repeated full-screen illustration and no tiled screenshot backdrop**.
  Geography must determine terrain and landmark placement.
- Avatar: original higher-quality 16-bit top-down/3/4 action-RPG character,
  front/back/side poses and walk frames, cosmetic control for skin/hair/outfit.
  Do not alter unique warrior acquisition or global barcode blueprints.
- Spacetime Ruptures are distinct cyan portals for verified local venues.
  Wormholes are larger purple portals for verified production facilities.

## Venue truth and limitations
- Venue icon lat/lon is derived from a returned real business's geo point.
  Polygons/relations can provide approximate centers, **not entrances**; don't
  quietly substitute a fake entrance or relocate icons into a different block.
- Refresh asynchronously and cache nearby real venue data. A failed public
  Overpass service should be reported and not represented as zero businesses.
- Alcohol-serving restaurants must have sufficient qualifying source evidence
  instead of including every restaurant.
- A visible portal is anchored by coordinates and maintained across tile reloads;
  panning and zoom must not create duplicates or wrap-around copies.
- The online prototype is **not evidence of production-level venue accuracy**.

## UI and Android
- Full-screen game first; compact round controls, readable bottom navigation,
  adequate safe-area padding for modern Galaxy Android phones, touch-first.
- Native game and browser proof-of-concept are separate. Deployment success
  does not prove runtime or visual correctness.

## Acceptance tests
- In a deterministic 390×844 mobile browser test with mocked local vector
  geometry and GPS, verify: GPS permission, map source loading, displayed
  georeferenced avatar, *visible geography-derived art* and no JavaScript errors.
- Static scenic illustration must be hidden when the live world is selected.
- Simulate player motion vs stationary jitter; avatar should move only for real
  accepted position changes.
- Pan/rotate and reopen the app without duplicating or relocating world portals.
- If venue provider is unavailable, show a clear 'venue data unavailable'
  message while keeping the correct GPS map visible.
- Visually inspect **actual Android screenshots** against the user reference
  before claiming the appearance is complete.

## Current implementation status
A canvas renderer exists at `web/overworld/game-world.js`; it draws real
geographic shapes with pixel art. It is a prototype, not a hand-authored
3D/2.5D game engine. Future iteration should harden map data coverage, avatar
animation art, correct polygon center behavior, and device performance.