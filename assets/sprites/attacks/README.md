# Attack sprite sheets (individual characters only)

Place each class’s attack PNG here. **Do not** use `export/all_character_*.png`
contact sheets as atlases.

## Pirate (preferred path)

Preferred location for the isolated test and loader:

```
res://assets/animations/01_Pirate_Attack.png
```

Legacy fallbacks under this folder:

- `pirate_attack.png`
- `pirate_cutlass_attack_sprite_sheet.png`
- `pirate_sword_attack.png`

Authored layout: **3 columns × 3 rows** on a **1024×1536** sheet.

Manual region boundaries:

| | x0 | x1 |
|---|---|---|
| cols | 0, 341, 683 | 1024 |

| | y0 | y1 |
|---|---|---|
| rows | 0, 512, 1024 | 1536 |

## Curated frame order (NOT all 9 cells)

```
0 → 1 → 4 → 7 → 0
```

Excluded: `2, 3, 5, 6, 8` (duplicates / clipped blades / missing sword).

Source art faces **LEFT**. Facing right uses `AnimatedSprite2D.flip_h = true` only.

Inspect with:

```bash
python3 tools/extract_pirate_attack.py
```

## Import (pixel-perfect)

- Compress: **Lossless**
- Mipmaps: **Off**
- Project filter is already Nearest
- `PlayerAnimController` forces `texture_filter = TEXTURE_FILTER_NEAREST`
