# Live Events

Players fetch `live_events.json` on launch (with bundled + cached fallbacks).

## Publish workflow (developer)

1. Install the **Libation Warriors DEV** APK (`export/LibationWarriors-Dev.apk`).
2. Open **Event Admin** from the main menu.
3. Create/edit events (special dungeon and/or special barcodes).
4. Tap **Export JSON** — copies JSON to the clipboard and writes `user://live_events_export.json`.
5. Replace this file (`events/live_events.json`) in the repo with that JSON and push.
6. Public builds pick up the change on next **Refresh events** / app launch.

## Event fields

- `id`, `title`, `description`, `enabled`
- `starts_at` / `ends_at` — ISO-8601 UTC (`YYYY-MM-DD` or `YYYY-MM-DDTHH:MM:SSZ`)
- `special_dungeon` — optional themed Adventure dungeon
- `special_barcodes` — camera-scannable codes that unlock rare warriors during the window

Special barcodes should use an `EVENT-...` prefix so they are distinct from retail UPCs.
