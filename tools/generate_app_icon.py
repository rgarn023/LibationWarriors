#!/usr/bin/env python3
"""Build Chrono Trigger / SNES-style app icons for Libation Warriors.

Keeps the warrior hero art, but makes bottles / tankards read clearly at
launcher sizes so the "libations" theme is obvious.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / "assets" / "sprites"
ICONS = ROOT / "assets" / "icons"
ICONS.mkdir(parents=True, exist_ok=True)
ART = Path("/opt/cursor/artifacts")
ART.mkdir(parents=True, exist_ok=True)


def nearest(im: Image.Image, size: int) -> Image.Image:
    return im.resize((size, size), Image.Resampling.NEAREST)


def make_backdrop(size: int = 128) -> Image.Image:
    """Pixel backdrop: deep cellar gradient + vignette frame."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / max(1, size - 1)
        r = int(28 + 40 * (1 - t))
        g = int(18 + 22 * (1 - t))
        b = int(42 + 18 * t)
        d.line([(0, y), (size - 1, y)], fill=(r, g, b, 255))
    for y in range(0, size, 4):
        for x in range(0, size, 4):
            if (x // 4 + y // 4) % 2 == 0:
                d.rectangle([x, y, x + 3, y + 3], fill=(255, 255, 255, 10))
    # Amber rim
    d.rectangle([0, 0, size - 1, size - 1], outline=(196, 140, 48, 255))
    d.rectangle([1, 1, size - 2, size - 2], outline=(120, 80, 28, 255))
    d.rectangle([2, 2, size - 3, size - 3], outline=(60, 40, 20, 255))
    for cx, cy in [(6, 6), (size - 7, 6), (6, size - 7), (size - 7, size - 7)]:
        d.rectangle([cx, cy, cx + 2, cy + 2], fill=(212, 168, 56, 255))
    return img


def draw_amber_bottle(d: ImageDraw.ImageDraw, ox: int, oy: int, scale: int = 1) -> None:
    """Recognizable corked amber bottle (no brand marks)."""
    s = scale
    # Cork
    d.rectangle([ox + 5 * s, oy + 0 * s, ox + 10 * s, oy + 3 * s], fill=(120, 72, 36, 255))
    d.rectangle([ox + 6 * s, oy + 1 * s, ox + 9 * s, oy + 2 * s], fill=(168, 110, 55, 255))
    # Neck
    d.rectangle([ox + 5 * s, oy + 3 * s, ox + 10 * s, oy + 12 * s], fill=(110, 58, 22, 255))
    d.rectangle([ox + 6 * s, oy + 4 * s, ox + 8 * s, oy + 11 * s], fill=(196, 120, 42, 255))
    # Shoulder
    d.rectangle([ox + 3 * s, oy + 12 * s, ox + 12 * s, oy + 16 * s], fill=(96, 48, 18, 255))
    d.rectangle([ox + 4 * s, oy + 13 * s, ox + 11 * s, oy + 15 * s], fill=(170, 95, 30, 255))
    # Body
    d.rectangle([ox + 2 * s, oy + 16 * s, ox + 13 * s, oy + 42 * s], fill=(88, 42, 14, 255))
    d.rectangle([ox + 3 * s, oy + 17 * s, ox + 12 * s, oy + 41 * s], fill=(168, 92, 28, 255))
    # Liquid fill
    d.rectangle([ox + 3 * s, oy + 24 * s, ox + 12 * s, oy + 41 * s], fill=(140, 70, 18, 255))
    d.rectangle([ox + 4 * s, oy + 25 * s, ox + 11 * s, oy + 40 * s], fill=(196, 110, 36, 255))
    # Gloss highlight
    d.rectangle([ox + 4 * s, oy + 18 * s, ox + 5 * s, oy + 34 * s], fill=(255, 220, 130, 200))
    # Base
    d.rectangle([ox + 2 * s, oy + 41 * s, ox + 13 * s, oy + 43 * s], fill=(60, 28, 10, 255))


def draw_tankard(d: ImageDraw.ImageDraw, ox: int, oy: int, scale: int = 1) -> None:
    """Foamy beer / mead tankard."""
    s = scale
    # Foam head
    d.rectangle([ox + 1 * s, oy + 0 * s, ox + 12 * s, oy + 4 * s], fill=(240, 230, 190, 255))
    d.rectangle([ox + 2 * s, oy + 1 * s, ox + 4 * s, oy + 3 * s], fill=(255, 250, 220, 255))
    d.rectangle([ox + 7 * s, oy + 1 * s, ox + 10 * s, oy + 3 * s], fill=(255, 250, 220, 255))
    # Mug body
    d.rectangle([ox + 1 * s, oy + 4 * s, ox + 12 * s, oy + 20 * s], fill=(150, 110, 55, 255))
    d.rectangle([ox + 2 * s, oy + 5 * s, ox + 11 * s, oy + 19 * s], fill=(196, 150, 70, 255))
    # Ale
    d.rectangle([ox + 2 * s, oy + 7 * s, ox + 11 * s, oy + 19 * s], fill=(190, 120, 35, 255))
    d.rectangle([ox + 3 * s, oy + 8 * s, ox + 5 * s, oy + 16 * s], fill=(230, 170, 70, 200))
    # Handle
    d.rectangle([ox + 12 * s, oy + 7 * s, ox + 15 * s, oy + 16 * s], fill=(150, 110, 55, 255))
    d.rectangle([ox + 13 * s, oy + 8 * s, ox + 14 * s, oy + 15 * s], fill=(40, 24, 12, 255))
    # Base
    d.rectangle([ox + 1 * s, oy + 19 * s, ox + 12 * s, oy + 21 * s], fill=(100, 70, 30, 255))


def draw_wine_glass(d: ImageDraw.ImageDraw, ox: int, oy: int, scale: int = 1) -> None:
    """Small wine goblet accent."""
    s = scale
    # Bowl
    d.rectangle([ox + 2 * s, oy + 0 * s, ox + 9 * s, oy + 8 * s], fill=(90, 30, 40, 255))
    d.rectangle([ox + 3 * s, oy + 1 * s, ox + 8 * s, oy + 7 * s], fill=(150, 40, 55, 255))
    d.rectangle([ox + 3 * s, oy + 3 * s, ox + 8 * s, oy + 7 * s], fill=(170, 45, 60, 255))
    d.rectangle([ox + 4 * s, oy + 2 * s, ox + 5 * s, oy + 5 * s], fill=(220, 120, 130, 180))
    # Stem + foot
    d.rectangle([ox + 5 * s, oy + 8 * s, ox + 6 * s, oy + 14 * s], fill=(180, 170, 150, 255))
    d.rectangle([ox + 2 * s, oy + 14 * s, ox + 9 * s, oy + 15 * s], fill=(180, 170, 150, 255))


def make_libation_props(size: int = 128) -> Image.Image:
    """Foreground/background drink props that read at small sizes."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # Large amber bottle behind/right of warrior
    draw_amber_bottle(d, size - 34, 26, scale=2)
    # Tankard lower-left
    draw_tankard(d, 10, size - 52, scale=2)
    # Small wine glass mid-left (behind warrior a bit)
    draw_wine_glass(d, 14, 34, scale=2)
    # Splash / drip accents (amber droplets)
    for px, py in [(22, 78), (28, 86), (size - 28, 88), (size - 22, 96)]:
        d.rectangle([px, py, px + 2, py + 3], fill=(212, 150, 48, 200))
        d.rectangle([px, py, px + 2, py + 1], fill=(255, 220, 120, 220))
    return layer


def make_top_badge(size: int = 128) -> Image.Image:
    """Top plaque with tiny crossed bottle + mug mark."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    gx, gy = size // 2 - 10, 6
    d.rectangle([gx, gy, gx + 20, gy + 10], fill=(24, 16, 12, 255))
    d.rectangle([gx + 1, gy + 1, gx + 19, gy + 9], fill=(212, 152, 48, 255))
    d.rectangle([gx + 2, gy + 2, gx + 18, gy + 8], fill=(140, 90, 28, 255))
    # Mini bottle
    d.rectangle([gx + 5, gy + 3, gx + 7, gy + 8], fill=(196, 120, 42, 255))
    d.rectangle([gx + 5, gy + 2, gx + 7, gy + 3], fill=(120, 72, 36, 255))
    # Mini mug
    d.rectangle([gx + 11, gy + 4, gx + 16, gy + 8], fill=(230, 200, 110, 255))
    d.rectangle([gx + 12, gy + 5, gx + 15, gy + 8], fill=(196, 130, 40, 255))
    d.rectangle([gx + 16, gy + 5, gx + 17, gy + 7], fill=(230, 200, 110, 255))
    return layer


def compose_icon(base_size: int = 128) -> Image.Image:
    bg = make_backdrop(base_size)
    props = make_libation_props(base_size)
    warrior = Image.open(SPRITES / "pirate.png").convert("RGBA")
    target_h = int(base_size * 0.78)
    scale = target_h / warrior.height
    tw, th = max(1, int(warrior.width * scale)), max(1, int(warrior.height * scale))
    warrior = warrior.resize((tw, th), Image.Resampling.NEAREST)

    shadow = Image.new("RGBA", (base_size, base_size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sx = (base_size - tw) // 2 + 2
    sy = base_size - th - 10
    sd.ellipse([sx + 6, sy + th - 10, sx + tw - 6, sy + th - 2], fill=(0, 0, 0, 90))

    out = Image.alpha_composite(bg, props)
    out = Image.alpha_composite(out, shadow)
    out.paste(warrior, (sx, sy), warrior)
    # Props in front at the bottom corners so drinks stay visible over the warrior
    front = Image.new("RGBA", (base_size, base_size), (0, 0, 0, 0))
    fd = ImageDraw.Draw(front)
    draw_tankard(fd, 8, base_size - 48, scale=2)
    # Bottle neck peeking on the right in front
    draw_amber_bottle(fd, base_size - 30, 48, scale=1)
    out = Image.alpha_composite(out, front)
    badge = make_top_badge(base_size)
    out = Image.alpha_composite(out, badge)
    return out


def to_opaque(im: Image.Image, bg=(28, 18, 42, 255)) -> Image.Image:
    base = Image.new("RGBA", im.size, bg)
    return Image.alpha_composite(base, im.convert("RGBA"))


def adaptive_foreground(src: Image.Image, size: int = 432) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    content = src.resize((int(size * 0.72), int(size * 0.72)), Image.Resampling.NEAREST)
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
    step = max(8, size // 32)
    for y in range(0, size, step):
        for x in range(0, size, step):
            if (x // step + y // step) % 2 == 0:
                d.rectangle([x, y, x + step - 1, y + step - 1], fill=(255, 255, 255, 12))
    return img


def main() -> None:
    master = compose_icon(128)
    icon_512 = nearest(to_opaque(master), 512)
    icon_512.save(ICONS / "app_icon.png")
    master.save(ICONS / "app_icon_128.png")
    nearest(master, 256).save(ICONS / "app_icon_256.png")

    main_192 = nearest(to_opaque(master), 192)
    main_192.save(ICONS / "icon_192.png")

    fg = adaptive_foreground(master, 432)
    fg.save(ICONS / "adaptive_foreground_432.png")
    bg = adaptive_background(432)
    bg.save(ICONS / "adaptive_background_432.png")

    preview = nearest(to_opaque(master), 512)
    preview.save(ART / "app_icon.png")
    nearest(to_opaque(master), 192).save(ART / "app_icon_192.png")
    print("Wrote icons to", ICONS)


if __name__ == "__main__":
    main()
