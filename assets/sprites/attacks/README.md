# Attack sprite sheets

Drop your per-class attack PNGs here using these exact names (or update
`CharacterAnimationLibrary` if you rename them):

| Class | File |
|---|---|
| WhiteMage | `white_mage_holy_casting_sprite_sheet.png` |
| BlackMage | `shadowspell_black_mage_sprite_sheet.png` |
| Brawler | `punch_combo_pixel_sprite_sheet.png` |
| Samurai | `samurai_katana_attack_sprite_sheet.png` |
| Viking | `viking_heavy_axe_attack_sprite_sheet.png` |
| Rogue | `rogue_dagger_attack_sprite_sheet.png` |
| Nimrod | `nimrod_s_woodland_club_attack_animation.png` |

## Pixel-perfect Import (Godot 4)

For each PNG, select it in the FileSystem dock → **Import**:

1. **Compress** → `Lossless` (mode 0)
2. **Mipmaps** → Off
3. Leave size limit at 0
4. Click **Reimport**

Project-wide Nearest filtering is already set in `project.godot`:

```
textures/canvas_textures/default_texture_filter=0
```

`AnimatedCharacter` also forces:

```gdscript
texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
```

After dropping files, run:

```bash
godot --headless --path . --import
# optional helper that writes .import stubs:
python3 tools/write_pixel_import.py assets/sprites/attacks
```

Then open `res://scenes/animation/character_anim_test.tscn` and press **Space**.
