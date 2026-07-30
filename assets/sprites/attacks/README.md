# Attack sprite sheets (individual characters only)

Place each class’s attack PNG here. **Do not** use `export/all_character_*.png`
contact sheets as atlases.

## Pirate (required for sword-frame attacks)

Preferred filename:

```
pirate_attack.png
```

Also accepted:

- `pirate_cutlass_attack_sprite_sheet.png`
- `pirate_sword_attack.png`

Authored layout: **3 columns × 3 rows** on a ~1024×1536 sheet.

Manual region boundaries (scaled if the PNG size differs):

| | x0 | x1 |
|---|---|---|
| cols | 0, 341, 683 | 1024 |

| | y0 | y1 |
|---|---|---|
| rows | 0, 512, 1024 | 1536 |

Reading order (L→R, T→B):
1 Ready · 2 Anticipation · 3 Sword raised · 4 Swing begins · 5 Main slash · 6 Impact · 7 Follow-through · 8 Recovery · 9 Return pose (optional)

Inspect with:

```bash
python3 tools/extract_pirate_attack.py
```

## Import (pixel-perfect)

- Compress: **Lossless**
- Mipmaps: **Off**
- Project filter is already Nearest
- `PlayerAnimController` forces `texture_filter = TEXTURE_FILTER_NEAREST`
