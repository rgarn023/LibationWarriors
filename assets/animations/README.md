# Pirate attack animations

Place the individual Pirate attack sprite sheet here:

```
01_Pirate_Attack.png
```

Expected size: **1024 × 1536** (3×3 cells)

## Curated frame order (NOT all 9 cells)

`AttackAnimationTest` uses source cells:

`0 → 1 → 4 → 7 → 0`

Excluded: `2, 3, 5, 6, 8` (duplicates / clipped blades / missing sword).

Source art faces **LEFT**. When the player faces right: `AttackSprite.flip_h = true`.

Do **not** put the combined all-character contact sheet here.
