#!/usr/bin/env python3
"""Extract Pirate 3x3 attack frames using manual boundaries (no content-trim).

Expected source: assets/sprites/attacks/pirate_attack.png
  authored layout ~1024x1536 with x=[0,341,683,1024] y=[0,512,1024,1536]

Writes preview cells to /tmp/pirate_attack_cells/ for inspection.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CANDIDATES = [
    ROOT / "assets/animations/01_Pirate_Attack.png",
    ROOT / "assets/sprites/attacks/pirate_attack.png",
    ROOT / "assets/sprites/attacks/pirate_cutlass_attack_sprite_sheet.png",
    ROOT / "assets/sprites/attacks/pirate_sword_attack.png",
]
# Curated usable cells only (exclude 2, 3, 5, 6, 8).
CURATED = [0, 1, 4, 7, 0]
X = [0, 341, 683, 1024]
Y = [0, 512, 1024, 1536]
PHASES = [
    "Ready",
    "Anticipation",
    "Sword raised",
    "Swing begins",
    "Main slash",
    "Impact",
    "Follow-through",
    "Recovery",
    "Return pose",
]


def main() -> int:
    src = next((p for p in CANDIDATES if p.exists()), None)
    if src is None:
        print("MISSING pirate attack PNG. Place it at:")
        for p in CANDIDATES:
            print(" ", p.relative_to(ROOT))
        return 1
    im = Image.open(src).convert("RGBA")
    print("source", src.relative_to(ROOT), im.size)
    sx = im.width / 1024.0
    sy = im.height / 1536.0
    xs = [int(round(v * sx)) for v in X]
    ys = [int(round(v * sy)) for v in Y]
    out = Path("/tmp/pirate_attack_cells")
    out.mkdir(parents=True, exist_ok=True)
    mw = max(xs[i + 1] - xs[i] for i in range(3))
    mh = max(ys[i + 1] - ys[i] for i in range(3))
    kept = 0
    for row in range(3):
        for col in range(3):
            i = row * 3 + col
            cell = im.crop((xs[col], ys[row], xs[col + 1], ys[row + 1]))
            opaque = sum(1 for p in cell.getdata() if p[3] > 20)
            ratio = opaque / max(1, cell.width * cell.height)
            path = out / f"{i:02d}_{PHASES[i].replace(' ', '_').lower()}.png"
            # Bottom-center onto shared canvas (NO content trim).
            canvas = Image.new("RGBA", (mw, mh), (0, 0, 0, 0))
            dx = (mw - cell.width) // 2
            dy = mh - cell.height
            canvas.paste(cell, (dx, dy), cell)
            canvas.save(path)
            curated = "CURATED" if i in set(CURATED) else "EXCLUDE"
            status = "KEEP" if ratio >= 0.008 else "SKIP?"
            print(f"{status}/{curated} {i} {PHASES[i]:16s} {cell.size} opaque={ratio:.3f} -> {path.name}")
            if ratio >= 0.008:
                kept += 1
    print(f"curated order={CURATED}")
    print(f"kept≈{kept}/9 canvas={mw}x{mh}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
