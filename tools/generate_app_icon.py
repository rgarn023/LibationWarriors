#!/usr/bin/env python3
"""Build Chrono Trigger / SNES-style app icons for Libation Warriors."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / "assets" / "sprites"
ICONS = ROOT / "assets" / "icons"
ICONS.mkdir(parents=True, exist_ok=True)


def nearest(im: Image.Image, size: int) -> Image.Image:
    return im.resize((size, size), Image.Resampling.NEAREST)


def make_backdrop(size: int = 128) -> Image.Image:
    """Pixel backdrop: deep cellar gradient + vignette frame."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Vertical gradient cellar tones
    for y in range(size):
        t = y / max(1, size - 1)
        r = int(28 + 40 * (1 - t))
        g = int(18 + 22 * (1 - t))
        b = int(42 + 18 * t)
        d.line([(0, y), (size - 1, y)], fill=(r, g, b, 255))
    # Pixel checker soft texture
    for y in range(0, size, 4):
        for x in range(0, size, 4):
            if (x // 4 + y // 4) % 2 == 0:
                d.rectangle([x, y, x + 3, y + 3], fill=(255, 255, 255, 10))
    # Amber rim light
    d.rectangle([0, 0, size - 1, size - 1], outline=(196, 140, 48, 255))
    d.rectangle([1, 1, size - 2, size - 2], outline=(120, 80, 28, 255))
    d.rectangle([2, 2, size - 3, size - 3], outline=(60, 40, 20, 255))
    # Corner studs
    for cx, cy in [(6, 6), (size - 7, 6), (6, size - 7), (size - 7, size - 7)]:
        d.rectangle([cx, cy, cx + 2, cy + 2], fill=(212, 168, 56, 255))
    return img


def make_bottle_deco(size: int = 128) -> Image.Image:
    """Tiny pixel bottle silhouette behind the warrior (no brand)."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # Bottle body right side
    bx = size - 38
    d.rectangle([bx + 8, 28, bx + 22, 36], fill=(80, 50, 30, 180))  # neck
    d.rectangle([bx + 6, 36, bx + 24, 90], fill=(120, 70, 28, 160))  # body
    d.rectangle([bx + 8, 40, bx + 22, 86], fill=(180, 110, 40, 120))
    d.rectangle([bx + 10, 42, bx + 14, 70], fill=(255, 220, 120, 90))  # gloss
    return layer


def compose_icon(base_size: int = 128) -> Image.Image:
    bg = make_backdrop(base_size)
    bottle = make_bottle_deco(base_size)
    warrior = Image.open(SPRITES / "pirate.png").convert("RGBA")
    # Scale warrior to dominate icon while keeping nearest-neighbor
    target_h = int(base_size * 0.82)
    scale = target_h / warrior.height
    tw, th = int(warrior.width * scale), int(warrior.height * scale)
    warrior = warrior.resize((tw, th), Image.Resampling.NEAREST)
    # Soft pixel shadow
    shadow = Image.new("RGBA", (base_size, base_size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sx = (base_size - tw) // 2 + 2
    sy = base_size - th - 8
    sd.ellipse([sx + 6, sy + th - 10, sx + tw - 6, sy + th - 2], fill=(0, 0, 0, 90))
    out = Image.alpha_composite(bg, bottle)
    out = Image.alpha_composite(out, shadow)
    out.paste(warrior, (sx, sy), warrior)
    # Small amber "LW" gem at top — brand mark without text clutter
    d = ImageDraw.Draw(out)
    gx, gy = base_size // 2 - 5, 8
    d.rectangle([gx, gy, gx + 10, gy + 6], fill=(24, 16, 12, 255))
    d.rectangle([gx + 1, gy + 1, gx + 9, gy + 5], fill=(212, 152, 48, 255))
    d.rectangle([gx + 3, gy + 2, gx + 4, gy + 4], fill=(255, 230, 140, 255))
    return out


def to_opaque(im: Image.Image, bg=(28, 18, 42, 255)) -> Image.Image:
    base = Image.new("RGBA", im.size, bg)
    return Image.alpha_composite(base, im.convert("RGBA"))


def adaptive_foreground(src: Image.Image, size: int = 432) -> Image.Image:
    """Safe-zone adaptive foreground: warrior centered in 66% safe area."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    # Keep content in center ~66%
    content = src.resize((int(size * 0.66), int(size * 0.66)), Image.Resampling.NEAREST)
    x = (size - content.width) // 2
    y = (size - content.height) // 2
    canvas.paste(content, (x, y), content)
    return canvas


def adaptive_background(size: int = 432) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / max(1, size - 1)
        r = int(28 + 36 * (1 - t))
        g = int(18 + 18 * (1 - t))
        b = int(42 + 20 * t)
        d.line([(0, y), (size - 1, y)], fill=(r, g, b, 255))
    # Subtle pixel pattern
    step = max(8, size // 32)
    for y in range(0, size, step):
        for x in range(0, size, step):
            if (x // step + y // step) % 2 == 0:
                d.rectangle([x, y, x + step - 1, y + step - 1], fill=(255, 255, 255, 12))
    return img


def main() -> None:
    master = compose_icon(128)
    # Godot project icon (square PNG)
    icon_512 = nearest(to_opaque(master), 512)
    icon_512.save(ICONS / "app_icon.png")
    # Also save master pixel art
    master.save(ICONS / "app_icon_128.png")
    nearest(master, 256).save(ICONS / "app_icon_256.png")

    # Android launcher
    main_192 = nearest(to_opaque(master), 192)
    main_192.save(ICONS / "icon_192.png")

    fg = adaptive_foreground(master, 432)
    fg.save(ICONS / "adaptive_foreground_432.png")
    bg = adaptive_background(432)
    bg.save(ICONS / "adaptive_background_432.png")

    # Preview for artifacts
    preview = nearest(to_opaque(master), 512)
    preview.save(Path("/opt/cursor/artifacts/app_icon.png"))
    print("Wrote icons to", ICONS)


if __name__ == "__main__":
    main()
