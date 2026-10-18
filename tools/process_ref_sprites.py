#!/usr/bin/env python3
"""Convert Chrono Trigger-style reference renders into game sprites."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SRC_DIRS = [
    Path("/opt/cursor/artifacts/assets"),
    ROOT / "assets" / "refs",
]
OUT = ROOT / "assets" / "sprites"
OUT.mkdir(parents=True, exist_ok=True)
REFS = ROOT / "assets" / "refs"
REFS.mkdir(parents=True, exist_ok=True)

W, H = 64, 80  # higher res SNES battle-sprite scale
PREVIEW = 3

FACTIONS = [
    "pirate", "militiaman", "bandit", "druid", "barbarian", "paladin",
    "alchemist", "bard", "red_mage", "white_mage", "black_mage", "brawler",
    "samurai", "viking", "rogue", "nimrod",
]


def find_src(faction: str) -> Path | None:
    name = f"ref_{faction}.png"
    for d in SRC_DIRS:
        p = d / name
        if p.exists():
            return p
    return None


def flood_bg_to_alpha(im: Image.Image, tol: int = 28) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    # Sample corners for bg color
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    # Average corner
    br = sum(c[0] for c in corners) // 4
    bg = sum(c[1] for c in corners) // 4
    bb = sum(c[2] for c in corners) // 4

    def near(c):
        return abs(c[0] - br) <= tol and abs(c[1] - bg) <= tol and abs(c[2] - bb) <= tol

    # Flood from edges
    stack = []
    for x in range(w):
        stack.append((x, 0))
        stack.append((x, h - 1))
    for y in range(h):
        stack.append((0, y))
        stack.append((w - 1, y))
    seen = set()
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or x < 0 or y < 0 or x >= w or y >= h:
            continue
        seen.add((x, y))
        c = px[x, y]
        if not near(c):
            continue
        px[x, y] = (0, 0, 0, 0)
        stack.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
    # Also clear remaining near-bg low-alpha-ish pixels that are isolated near edges
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if c[3] > 0 and near(c) and (x < 3 or y < 3 or x >= w - 3 or y >= h - 3):
                px[x, y] = (0, 0, 0, 0)
    return im


def autocrop(im: Image.Image, pad: int = 2) -> Image.Image:
    bbox = im.split()[-1].getbbox()
    if not bbox:
        return im
    l, t, r, b = bbox
    l = max(0, l - pad)
    t = max(0, t - pad)
    r = min(im.width, r + pad)
    b = min(im.height, b + pad)
    return im.crop((l, t, r, b))


def fit_canvas(im: Image.Image, tw: int, th: int) -> Image.Image:
    # Scale to fit height mostly
    scale = min(tw / im.width, th / im.height)
    nw = max(1, int(im.width * scale))
    nh = max(1, int(im.height * scale))
    # Prefer slightly pixel-crisp: resize with BOX then NEAREST if downscaling a lot
    if scale < 0.5:
        im2 = im.resize((nw, nh), Image.Resampling.BOX)
    else:
        im2 = im.resize((nw, nh), Image.Resampling.LANCZOS)
    # Light posterize toward 16-bit palette feel
    rgb = im2.convert("RGB").quantize(colors=48, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    alpha = im2.split()[-1]
    rgb.putalpha(alpha)
    canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    x = (tw - nw) // 2
    y = th - nh  # feet on bottom
    canvas.paste(rgb, (x, y), rgb)
    return canvas


def make_sheet(frame: Image.Image) -> Image.Image:
    sheet = Image.new("RGBA", (W * 4, H), (0, 0, 0, 0))
    for i, bob in enumerate([0, -1, 0, 1]):
        fr = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        fr.paste(frame, (0, bob), frame)
        sheet.paste(fr, (i * W, 0), fr)
    return sheet


def main() -> None:
    # Copy refs into project for provenance
    for f in FACTIONS:
        src = find_src(f)
        if src:
            (REFS / f"ref_{f}.png").write_bytes(src.read_bytes())

    for f in FACTIONS:
        src = find_src(f)
        if src is None:
            print("MISSING", f)
            continue
        im = Image.open(src)
        im = flood_bg_to_alpha(im, tol=32)
        im = autocrop(im, pad=4)
        frame = fit_canvas(im, W, H)
        sheet = make_sheet(frame)
        frame.save(OUT / f"{f}.png")
        sheet.save(OUT / f"{f}_sheet.png")
        frame.resize((W * PREVIEW, H * PREVIEW), Image.Resampling.NEAREST).save(
            OUT / f"{f}_preview.png"
        )
        print("processed", f, frame.size)

    (OUT / "factions.txt").write_text("\n".join(FACTIONS) + "\n")

    # Collage
    cols = 4
    cell = 220
    rows = (len(FACTIONS) + cols - 1) // cols
    coll = Image.new("RGBA", (cols * cell, rows * cell), (10, 8, 18, 255))
    for i, f in enumerate(FACTIONS):
        p = OUT / f"{f}_preview.png"
        if not p.exists():
            continue
        im = Image.open(p).convert("RGBA")
        # fit in cell
        sc = min((cell - 20) / im.width, (cell - 20) / im.height)
        im = im.resize((int(im.width * sc), int(im.height * sc)), Image.Resampling.NEAREST)
        x = (i % cols) * cell + (cell - im.width) // 2
        y = (i // cols) * cell + (cell - im.height) // 2
        coll.paste(im, (x, y), im)
    coll.save("/opt/cursor/artifacts/faction_sprites.png")
    print("collage written")


if __name__ == "__main__":
    main()
