# Pirate Warrior — Phase 1 (design review)

Original Libation Warriors pirate battle character.  
**Not** derived from the rejected blocky sheet.

## Review these first

| File | Pose |
|------|------|
| `pirate_master_idle.png` | Ready / neutral battle stance |
| `pirate_attack_anticipation.png` | Weight back, sword raised behind |
| `pirate_attack_lunge.png` | Forward step, swing begins |
| `pirate_attack_swing.png` | Main diagonal slash |
| `pirate_attack_impact.png` | Full extension / impact |
| `pirate_attack_followthrough.png` | Follow-through |

Also:

- `pirate_phase1_poses_preview_x5.png` — 5× nearest preview (checker shows transparency)
- `pirate_phase1_poses_strip_x4.png` — transparent strip
- `pirate_phase1_palette.png` — locked palette from master ready

## Specs

- Cell size: **64×64**
- Background: **transparent**
- Facing: **right**
- Standing height: **~56px** (crouch frames shorter by design)
- Foot baseline: **y = 59**
- Nearest-neighbor only after palette lock

## Out of scope until approved

No walk / hit / victory / left-facing / Godot wiring / full sheet packing yet.

Rebuild:

```bash
python3 tools/build_pirate_phase1_poses.py
```
