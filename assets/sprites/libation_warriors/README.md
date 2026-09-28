# Libation Warriors — Pirate Warrior (“Brine”)

Original 16-bit SNES-era JRPG sprite sheet for a recruitable pirate battle unit.
Inspired by Chrono Trigger–era craft; **original design** (not a copy of any character).

## Design

- Tricorn hat + crimson feather
- Deep sea-blue coat, burgundy vest, gold trim
- Cutlass / saber
- Green flask charm on belt (libation motif)
- Right-facing primary sheet (left sheet is mirrored)

## Files

| File | Description |
|------|-------------|
| `pirate_brine_sheet.png` | Primary **right-facing** sheet `512×320` (`64×64` cells) |
| `pirate_brine_sheet_left.png` | Left-facing convenience mirror |
| `pirate_brine_sheet.json` | Frame map + timings |
| `pirate_brine_sheet_preview_x2.png` | 2× nearest preview |

## Layout (8 columns × 5 rows)

```
Row 0  idle     cols 0–3   (4 frames)   linear 0–3
Row 1  walk     cols 0–5   (6 frames)   linear 8–13
Row 2  attack   cols 0–7   (8 frames)   linear 16–23
Row 3  hit      cols 0–2   (3 frames)   linear 24–26
Row 4  victory  cols 0–3   (4 frames)   linear 32–35
```

Pivot per cell: `(30, 58)`.

## Recommended timings (Godot FPS)

| Animation | Frames | FPS | Loop | Sec/frame |
|-----------|--------|-----|------|-----------|
| idle | 4 | 5.5 | yes | 0.18 |
| walk | 6 | 10 | yes | 0.10 |
| attack | 8 | 14 | no | 0.07 |
| hit | 3 | 12 | no | 0.08 |
| victory | 4 | 7 | no | 0.14 |

## Godot 4.7.1

Import: **Lossless**, mipmaps **off**, filter **Nearest**.

```gdscript
var frames := LibationPirateFrames.build_sprite_frames()
$AnimatedSprite2D.sprite_frames = frames
$AnimatedSprite2D.play("idle")
LibationPirateFrames.apply_facing($AnimatedSprite2D, facing_right)
```

Preview scene: `res://scenes/LibationPiratePreview.tscn`

Regenerate art:

```bash
python3 tools/generate_libation_pirate_sheet.py
```
