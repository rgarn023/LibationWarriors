# Character attack animation importer (Godot 4)

Reusable, per-character sprite-sheet → `SpriteFrames` pipeline for pixel-art
attacks. Sheets are **not** assumed identical; every class has its own config.

## Files

| Path | Role |
|---|---|
| `scripts/animation/character_animation_data.gd` | `CharacterAnimationData` resource fields |
| `scripts/animation/sprite_frames_builder.gd` | Builds `SpriteFrames` (idle + attack) |
| `scripts/animation/character_animation_library.gd` | **All class configs in one file** |
| `scripts/animation/animated_character.gd` | `AnimatedSprite2D` player (Space → attack) |
| `scripts/animation/character_anim_test.gd` | Test harness input |
| `scenes/animation/character_anim_test.tscn` | Node2D + AnimatedSprite2D test scene |
| `assets/sprites/attacks/` | Drop attack PNGs here |
| `tools/write_pixel_import.py` | Writes Nearest-friendly `.import` stubs |

## Quick start

1. Copy attack sheets into `assets/sprites/attacks/` (see README there).
2. Import each PNG as **Lossless**, **no mipmaps**.
3. Open `scenes/animation/character_anim_test.tscn` and press **F6**.
4. **Space** plays attack once → returns to idle on `animation_finished`.
5. **← / →** or **1–7** switches characters.

Until attack PNGs are present, the test scene falls back to the existing
`*_sheet.png` walk cycles so you can verify wiring.

## CharacterAnimationData fields

```gdscript
character_name      # "Samurai"
texture_path        # attack sheet
idle_texture_path   # optional walk/idle sheet
frame_width/height  # attack cell size (e.g. 64×80)
columns / rows      # 0 = auto from texture size
total_frames        # 0 = columns * rows
attack_fps
attack_loop         # must be false for one-shot → idle
sprite_offset       # pivot tweak (feet stay planted)
display_scale       # use 1, 2, 3… for crisp pixels
```

## Store all class configs in one file

`CharacterAnimationLibrary` holds every class. Add a new hero like this:

```gdscript
static func _my_hero() -> CharacterAnimationData:
    return _make(
        "MyHero",
        "my_hero_attack_sheet.png",
        "my_hero_sheet.png",
        64, 80,   # frame size
        6, 1, 6,  # columns, rows, total_frames (or 0,0,0 to auto-detect)
        12.0      # attack_fps
    )
```

Then register the name in `all_names()` and `get_data()`.

## Switch between characters

```gdscript
$AnimatedSprite2D.set_character("Viking")
$AnimatedSprite2D.cycle_next_character()
```

Or from the library directly:

```gdscript
var data := CharacterAnimationLibrary.get_data("Rogue")
sprite.sprite_frames = SpriteFramesBuilder.build(data)
```

## Keep the pivot visually stable

1. Author every frame on the **same canvas size** (e.g. 64×80) with feet on the same baseline.
2. Use `centered = true` (default in `AnimatedCharacter`).
3. If an attack sheet is taller/wider, set `sprite_offset` on that class’s
   `CharacterAnimationData` so the torso/feet line up with idle.
4. Do **not** change `offset` mid-animation unless you intentionally animate it.

## Nearest-neighbor import settings (Godot 4)

### Project (already set)

`project.godot`:

```
[rendering]
textures/canvas_textures/default_texture_filter=0   # 0 = Nearest
```

### Per PNG (Import dock)

- Compress → **Lossless**
- Mipmaps → **Off**
- Reimport

### Per node

```gdscript
animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
```

`AnimatedCharacter._ready()` already does this.

## Avoid blurry sprites when scaling

1. Scale by **integers only**: `scale = Vector2(2, 2)` not `1.5`.
2. Keep `display_scale` on the data resource at 1 / 2 / 3.
3. Camera zoom preferably integer or `.5` steps; stretch mode is `canvas_items`.
4. Never enable mipmaps on character sheets.
5. Don’t use `TEXTURE_FILTER_LINEAR` on the sprite or parent CanvasItem.

## Attack plays once → idle

`SpriteFramesBuilder` sets `attack_loop = false`.  
`AnimatedCharacter` connects `animation_finished`:

```gdscript
func _on_animation_finished() -> void:
    if animation == "attack":
        attack_finished.emit()
        play("idle")
```

## Measuring a new sheet

```bash
python3 - <<'PY'
from PIL import Image
im = Image.open("assets/sprites/attacks/samurai_katana_attack_sprite_sheet.png")
print(im.size)
# If frames are 64x80: columns = width//64, rows = height//80
PY
```

Then set `columns`, `rows`, `total_frames` on that class in the library
(or leave `0` to auto-detect).
