#!/usr/bin/env python3
"""Generate an original 16-bit JRPG pirate sprite sheet for Libation Warriors.

True pixel art (PIL), 64x64 frames, transparent background, right-facing.
Original design — not a copy of any existing character.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "sprites" / "libation_warriors"
ARTIFACT_DIR = Path("/opt/cursor/artifacts")
SCRIPTS_DIR = ROOT / "scripts" / "animation"

FRAME = 64
COLS = 8
ROWS = 5
# Consistent foot pivot inside each cell
PIVOT_X = 30
PIVOT_Y = 58

# Limited cohesive SNES palette
P = {
    "out": (22, 18, 16, 255),
    "skin": (236, 190, 152, 255),
    "skin_s": (200, 140, 108, 255),
    "skin_d": (168, 108, 82, 255),
    "hair": (36, 28, 22, 255),
    "hair_h": (70, 54, 40, 255),
    "hat": (44, 36, 30, 255),
    "hat_h": (76, 60, 48, 255),
    "hat_trim": (220, 176, 72, 255),
    "feather": (200, 36, 52, 255),
    "feather_h": (236, 96, 96, 255),
    "coat": (32, 70, 112, 255),
    "coat_h": (56, 110, 158, 255),
    "coat_s": (20, 46, 78, 255),
    "coat_trim": (220, 176, 72, 255),
    "vest": (138, 40, 48, 255),
    "vest_h": (176, 68, 74, 255),
    "shirt": (236, 224, 204, 255),
    "belt": (78, 48, 30, 255),
    "buckle": (220, 176, 72, 255),
    "pants": (48, 52, 68, 255),
    "pants_h": (74, 80, 100, 255),
    "boot": (96, 58, 38, 255),
    "boot_h": (128, 84, 56, 255),
    "boot_trim": (220, 176, 72, 255),
    "blade": (204, 214, 226, 255),
    "blade_h": (242, 246, 250, 255),
    "blade_s": (148, 158, 172, 255),
    "hilt": (92, 68, 48, 255),
    "guard": (220, 176, 72, 255),
    "flask": (64, 122, 72, 255),
    "flask_h": (108, 166, 108, 255),
    "flask_cap": (220, 176, 72, 255),
    "eye": (24, 18, 16, 255),
    "mouth": (150, 84, 72, 255),
    "scarf": (188, 40, 52, 255),
    "scarf_h": (220, 84, 88, 255),
    "trail": (236, 242, 250, 200),
}


def new_frame() -> Image.Image:
    return Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))


def px(img: Image.Image, x: int, y: int, c: tuple) -> None:
    if 0 <= x < FRAME and 0 <= y < FRAME and len(c) >= 4 and c[3] > 0:
        # Alpha blend over existing if semi-transparent
        if c[3] < 255:
            old = img.getpixel((x, y))
            if old[3] == 0:
                img.putpixel((x, y), c)
            else:
                a = c[3] / 255.0
                img.putpixel(
                    (x, y),
                    (
                        int(old[0] * (1 - a) + c[0] * a),
                        int(old[1] * (1 - a) + c[1] * a),
                        int(old[2] * (1 - a) + c[2] * a),
                        max(old[3], c[3]),
                    ),
                )
        else:
            img.putpixel((x, y), c)


def rect(img: Image.Image, x0: int, y0: int, x1: int, y1: int, c: tuple) -> None:
    if x1 < x0:
        x0, x1 = x1, x0
    if y1 < y0:
        y0, y1 = y1, y0
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(img, x, y, c)


def outline(img: Image.Image, x0: int, y0: int, x1: int, y1: int, c: tuple = None) -> None:
    c = c or P["out"]
    for x in range(x0, x1 + 1):
        px(img, x, y0, c)
        px(img, x, y1, c)
    for y in range(y0, y1 + 1):
        px(img, x0, y, c)
        px(img, x1, y, c)


def line(img: Image.Image, x0: int, y0: int, x1: int, y1: int, c: tuple) -> None:
    dx, dy = abs(x1 - x0), abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx - dy
    x, y = x0, y0
    while True:
        px(img, x, y, c)
        if x == x1 and y == y1:
            break
        e2 = 2 * err
        if e2 > -dy:
            err -= dy
            x += sx
        if e2 < dx:
            err += dx
            y += sy


def thick(img: Image.Image, x0: int, y0: int, x1: int, y1: int, c: tuple, w: int = 1) -> None:
    for ox in range(-w, w + 1):
        for oy in range(-w, w + 1):
            if ox * ox + oy * oy <= w * w:
                line(img, x0 + ox, y0 + oy, x1 + ox, y1 + oy, c)


def ellipse(img: Image.Image, cx: int, cy: int, rx: int, ry: int, c: tuple) -> None:
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            if ((x - cx) / max(rx, 1)) ** 2 + ((y - cy) / max(ry, 1)) ** 2 <= 1.08:
                px(img, x, y, c)


def draw_cutlass(img: Image.Image, hx: int, hy: int, tx: int, ty: int) -> None:
    # Guard
    rect(img, hx - 2, hy - 1, hx + 3, hy + 1, P["guard"])
    px(img, hx - 3, hy, P["out"])
    px(img, hx + 4, hy, P["out"])
    # Grip
    rect(img, hx, hy + 1, hx + 1, hy + 5, P["hilt"])
    px(img, hx, hy + 6, P["out"])
    # Blade body + highlight
    thick(img, hx + 1, hy - 1, tx, ty, P["blade_s"], 1)
    thick(img, hx + 1, hy - 2, tx, ty - 1, P["blade"], 1)
    line(img, hx + 1, hy - 2, tx, ty - 1, P["blade_h"])
    px(img, tx, ty, P["out"])
    px(img, tx + 1, ty - 1, P["blade_h"])


def draw_flask(img: Image.Image, x: int, y: int) -> None:
    rect(img, x, y, x + 2, y + 3, P["flask"])
    px(img, x + 1, y + 1, P["flask_h"])
    rect(img, x, y - 1, x + 2, y - 1, P["flask_cap"])
    # Tiny bottle label motif
    px(img, x + 1, y + 2, P["shirt"])
    px(img, x - 1, y + 1, P["out"])
    px(img, x + 3, y + 1, P["out"])


def draw_boot(img: Image.Image, x: int, y: int, facing_toe: int = 1) -> None:
    """Boot with toe pointing right (facing_toe=+1) by default."""
    rect(img, x, y - 3, x + 3, y, P["boot"])
    if facing_toe >= 0:
        rect(img, x + 3, y - 2, x + 5, y, P["boot"])  # toe right
        px(img, x + 4, y - 1, P["boot_h"])
    else:
        rect(img, x - 2, y - 2, x, y, P["boot"])
    rect(img, x, y - 2, x + 2, y - 1, P["boot_h"])
    rect(img, x, y - 3, x + 3, y - 3, P["boot_trim"])
    outline(img, x - (0 if facing_toe >= 0 else 2), y - 3, x + (5 if facing_toe >= 0 else 3), y)


def draw_pirate(
    img: Image.Image,
    *,
    breath: int = 0,
    leg_l: tuple[int, int] = (0, 0),
    leg_r: tuple[int, int] = (0, 0),
    lean: int = 0,
    head_dy: int = 0,
    arm: str = "ready",
    hurt: int = 0,
    smile: int = 0,
) -> None:
    """Right-facing 3/4 pirate. Feet on PIVOT_Y."""
    cx = PIVOT_X + lean
    base = PIVOT_Y
    torso_y = 27 - (1 if breath >= 2 else 0) + (1 if hurt else 0)
    head_y = torso_y - 12 + head_dy

    # --- Legs ---
    # Far (left) leg
    lx = cx - 6 + leg_l[0]
    ly = base + leg_l[1]
    rect(img, lx, torso_y + 15, lx + 3, ly - 3, P["pants"])
    rect(img, lx, torso_y + 15, lx + 1, ly - 7, P["pants_h"])
    draw_boot(img, lx, ly, 1)

    # Near (right) leg
    rx = cx + 1 + leg_r[0]
    ry = base + leg_r[1]
    rect(img, rx, torso_y + 15, rx + 3, ry - 3, P["pants"])
    rect(img, rx + 1, torso_y + 15, rx + 2, ry - 7, P["pants_h"])
    draw_boot(img, rx, ry, 1)

    # --- Coat / torso (3/4 — wider on right/near side) ---
    top, bot = torso_y, torso_y + 16
    rect(img, cx - 7, top, cx + 8, bot, P["coat"])
    rect(img, cx - 6, top + 1, cx + 6, bot - 2, P["coat_h"])
    rect(img, cx - 7, top + 3, cx - 5, bot, P["coat_s"])
    # Coat tails
    rect(img, cx - 8, bot - 1, cx - 4, bot + 5, P["coat"])
    rect(img, cx + 4, bot - 1, cx + 10, bot + 5, P["coat_h"])
    rect(img, cx - 8, bot, cx - 5, bot + 4, P["coat_s"])
    # Lapel gold
    line(img, cx - 1, top + 2, cx - 1, bot - 5, P["coat_trim"])
    line(img, cx + 2, top + 2, cx + 2, bot - 5, P["coat_trim"])
    # Vest + shirt
    rect(img, cx - 3, top + 3, cx + 4, bot - 3, P["vest"])
    rect(img, cx - 2, top + 4, cx + 3, bot - 5, P["vest_h"])
    rect(img, cx, top + 1, cx + 2, top + 4, P["shirt"])
    # Belt + buckle + flask
    rect(img, cx - 6, bot - 4, cx + 7, bot - 2, P["belt"])
    rect(img, cx, bot - 4, cx + 3, bot - 2, P["buckle"])
    px(img, cx + 1, bot - 3, P["hat_trim"])
    draw_flask(img, cx + 6, bot - 5)
    outline(img, cx - 7, top, cx + 8, bot)
    line(img, cx - 8, bot, cx - 4, bot + 5, P["out"])
    line(img, cx + 10, bot, cx + 5, bot + 5, P["out"])

    # Scarf
    rect(img, cx - 4, top + 1, cx + 5, top + 3, P["scarf"])
    px(img, cx + 5, top + 2, P["scarf_h"])
    line(img, cx - 5, top + 2, cx - 10, top + 7, P["scarf"])
    line(img, cx - 5, top + 3, cx - 9, top + 8, P["scarf_h"])

    # --- Arms / weapon ---
    sh_l = (cx - 7, top + 4)
    sh_r = (cx + 8, top + 4)

    def arm_hang(swing: int = 0) -> None:
        rect(img, sh_l[0] - 1, sh_l[1], sh_l[0] + 2, sh_l[1] + 9 + swing, P["coat"])
        rect(img, sh_l[0], sh_l[1] + 9 + swing, sh_l[0] + 2, sh_l[1] + 12 + swing, P["skin"])
        outline(img, sh_l[0] - 1, sh_l[1], sh_l[0] + 2, sh_l[1] + 12 + swing)

    if arm == "ready":
        arm_hang(0)
        hand = (sh_r[0] + 1, sh_r[1] + 9)
        rect(img, sh_r[0] - 2, sh_r[1], sh_r[0] + 2, hand[1] - 1, P["coat_h"])
        rect(img, hand[0] - 1, hand[1] - 1, hand[0] + 1, hand[1] + 1, P["skin"])
        outline(img, sh_r[0] - 2, sh_r[1], sh_r[0] + 2, hand[1] + 1)
        draw_cutlass(img, hand[0], hand[1], hand[0] + 11, hand[1] + 7)

    elif arm == "walk":
        # Opposite arm/leg swing encoded in leg_r[0] sign
        swing = -leg_r[0]
        arm_hang(swing)
        hand = (sh_r[0] + 1 + max(0, -swing), sh_r[1] + 9 - swing)
        rect(img, sh_r[0] - 2, sh_r[1], sh_r[0] + 2, hand[1] - 1, P["coat_h"])
        rect(img, hand[0] - 1, hand[1] - 1, hand[0] + 1, hand[1] + 1, P["skin"])
        draw_cutlass(img, hand[0], hand[1], hand[0] + 10, hand[1] + 8)

    elif arm == "windup":
        arm_hang(1)
        hand = (sh_r[0] - 2, sh_r[1] + 1)
        rect(img, sh_r[0] - 4, sh_r[1] - 1, sh_r[0] + 1, hand[1] + 3, P["coat_h"])
        rect(img, hand[0] - 1, hand[1], hand[0] + 1, hand[1] + 2, P["skin"])
        draw_cutlass(img, hand[0], hand[1], hand[0] - 1, hand[1] - 12)

    elif arm == "anticipation":
        arm_hang(1)
        hand = (sh_r[0] - 3, sh_r[1] - 3)
        rect(img, sh_r[0] - 5, sh_r[1] - 2, sh_r[0], hand[1] + 3, P["coat_h"])
        rect(img, hand[0] - 1, hand[1], hand[0] + 1, hand[1] + 2, P["skin"])
        draw_cutlass(img, hand[0], hand[1], hand[0] + 1, hand[1] - 15)

    elif arm == "swing_start":
        arm_hang(0)
        hand = (sh_r[0] + 2, sh_r[1] - 1)
        rect(img, sh_r[0] - 1, sh_r[1] - 2, sh_r[0] + 3, hand[1] + 3, P["coat_h"])
        rect(img, hand[0], hand[1], hand[0] + 2, hand[1] + 2, P["skin"])
        draw_cutlass(img, hand[0], hand[1], hand[0] + 12, hand[1] - 7)

    elif arm == "slash":
        arm_hang(-1)
        hand = (sh_r[0] + 5, sh_r[1] + 3)
        rect(img, sh_r[0], sh_r[1] + 1, hand[0], hand[1] + 1, P["coat_h"])
        rect(img, hand[0], hand[1] - 1, hand[0] + 2, hand[1] + 1, P["skin"])
        thick(img, hand[0] + 2, hand[1], hand[0] + 20, hand[1] - 1, P["blade"], 1)
        line(img, hand[0] + 2, hand[1] - 1, hand[0] + 20, hand[1] - 2, P["blade_h"])
        rect(img, hand[0] - 1, hand[1], hand[0] + 2, hand[1] + 2, P["guard"])
        rect(img, hand[0], hand[1] + 2, hand[0] + 1, hand[1] + 5, P["hilt"])
        for i, (sx, sy) in enumerate(
            [(hand[0] + 8, hand[1] - 3), (hand[0] + 13, hand[1] - 4), (hand[0] + 17, hand[1] - 3)]
        ):
            px(img, sx, sy, (242, 246, 250, 200 - i * 50))

    elif arm == "impact":
        arm_hang(-1)
        hand = (sh_r[0] + 6, sh_r[1] + 5)
        rect(img, sh_r[0], sh_r[1] + 2, hand[0], hand[1], P["coat_h"])
        rect(img, hand[0], hand[1] - 1, hand[0] + 2, hand[1] + 1, P["skin"])
        draw_cutlass(img, hand[0], hand[1], hand[0] + 15, hand[1] + 1)
        for sx, sy in [
            (hand[0] + 16, hand[1] - 2),
            (hand[0] + 17, hand[1] - 4),
            (hand[0] + 18, hand[1]),
            (hand[0] + 15, hand[1] - 3),
            (hand[0] + 16, hand[1] + 2),
        ]:
            px(img, sx, sy, P["blade_h"])

    elif arm == "follow":
        arm_hang(0)
        hand = (sh_r[0] + 3, sh_r[1] + 8)
        rect(img, sh_r[0] - 1, sh_r[1] + 3, hand[0], hand[1], P["coat_h"])
        rect(img, hand[0], hand[1], hand[0] + 2, hand[1] + 2, P["skin"])
        draw_cutlass(img, hand[0], hand[1], hand[0] + 9, hand[1] + 8)

    elif arm == "recover":
        arm_hang(0)
        hand = (sh_r[0] + 1, sh_r[1] + 8)
        rect(img, sh_r[0] - 2, sh_r[1], sh_r[0] + 2, hand[1], P["coat_h"])
        rect(img, hand[0] - 1, hand[1], hand[0] + 1, hand[1] + 2, P["skin"])
        draw_cutlass(img, hand[0], hand[1], hand[0] + 10, hand[1] + 7)

    elif arm == "return":
        arm_hang(0)
        hand = (sh_r[0] + 1, sh_r[1] + 9)
        rect(img, sh_r[0] - 2, sh_r[1], sh_r[0] + 2, hand[1], P["coat_h"])
        rect(img, hand[0] - 1, hand[1], hand[0] + 1, hand[1] + 2, P["skin"])
        draw_cutlass(img, hand[0], hand[1], hand[0] + 11, hand[1] + 7)

    elif arm == "hit":
        arm_hang(2)
        hand = (sh_r[0] + 2, sh_r[1] + 10)
        rect(img, sh_r[0] - 1, sh_r[1] + 2, sh_r[0] + 2, hand[1], P["coat_h"])
        rect(img, hand[0] - 1, hand[1], hand[0] + 1, hand[1] + 2, P["skin"])
        draw_cutlass(img, hand[0], hand[1], hand[0] + 6, hand[1] + 9)

    elif arm == "victory":
        arm_hang(-1)
        hand = (sh_r[0], sh_r[1] - 2 - smile)
        rect(img, sh_r[0] - 2, sh_r[1] - 3, sh_r[0] + 2, hand[1] + 3, P["coat_h"])
        rect(img, hand[0] - 1, hand[1], hand[0] + 1, hand[1] + 2, P["skin"])
        draw_cutlass(img, hand[0], hand[1], hand[0] + 2, hand[1] - 15)

    # --- Head (3/4 right) ---
    hx = cx + 2 + (1 if hurt else 0)
    hy = head_y
    rect(img, hx - 1, hy + 8, hx + 2, hy + 11, P["skin_s"])  # neck
    # Face mass
    ellipse(img, hx + 1, hy + 5, 6, 7, P["skin"])
    rect(img, hx - 3, hy + 2, hx + 6, hy + 10, P["skin"])
    rect(img, hx - 3, hy + 6, hx - 1, hy + 10, P["skin_s"])
    rect(img, hx + 4, hy + 5, hx + 6, hy + 9, P["skin_s"])
    rect(img, hx - 2, hy + 10, hx + 4, hy + 11, P["skin_d"])
    # Hair
    rect(img, hx - 4, hy + 1, hx + 6, hy + 3, P["hair"])
    px(img, hx + 6, hy + 4, P["hair_h"])
    px(img, hx - 4, hy + 4, P["hair"])
    # Eyes looking right
    if hurt >= 2:
        line(img, hx - 1, hy + 5, hx + 1, hy + 5, P["out"])
        line(img, hx + 3, hy + 5, hx + 5, hy + 5, P["out"])
    else:
        px(img, hx, hy + 5, P["eye"])
        px(img, hx + 1, hy + 5, P["eye"])
        px(img, hx + 3, hy + 5, P["eye"])
        px(img, hx + 4, hy + 5, P["eye"])
        px(img, hx + 4, hy + 4, P["shirt"])
    # Mouth
    if smile >= 2:
        line(img, hx + 1, hy + 8, hx + 4, hy + 8, P["mouth"])
        px(img, hx + 4, hy + 7, P["mouth"])
    elif hurt:
        line(img, hx + 1, hy + 9, hx + 3, hy + 8, P["mouth"])
    else:
        rect(img, hx + 1, hy + 8, hx + 3, hy + 8, P["mouth"])

    # Tricorn hat
    rect(img, hx - 6, hy, hx + 8, hy + 3, P["hat"])
    rect(img, hx - 5, hy - 3, hx + 6, hy, P["hat_h"])
    rect(img, hx - 3, hy - 5, hx + 4, hy - 3, P["hat"])
    # Brim points
    rect(img, hx - 9, hy + 1, hx - 5, hy + 3, P["hat"])
    rect(img, hx + 6, hy + 1, hx + 11, hy + 3, P["hat_h"])
    line(img, hx - 4, hy + 1, hx + 5, hy + 1, P["hat_trim"])
    # Feather to the right
    line(img, hx + 7, hy - 1, hx + 12, hy - 6, P["feather"])
    line(img, hx + 7, hy, hx + 11, hy - 5, P["feather_h"])
    px(img, hx + 12, hy - 7, P["feather"])
    # Hat outline
    line(img, hx - 9, hy + 1, hx - 3, hy - 5, P["out"])
    line(img, hx + 11, hy + 1, hx + 4, hy - 5, P["out"])
    line(img, hx - 3, hy - 5, hx + 4, hy - 5, P["out"])
    outline(img, hx - 3, hy + 2, hx + 6, hy + 11)


def build_animations() -> dict[str, list[Image.Image]]:
    anims: dict[str, list[Image.Image]] = {}

    # Idle 4 — breathing + slight weight shift
    idle_specs = [
        dict(breath=0, leg_l=(0, 0), leg_r=(0, 0), arm="ready"),
        dict(breath=1, leg_l=(0, 0), leg_r=(1, 0), arm="ready"),
        dict(breath=2, leg_l=(-1, 0), leg_r=(1, 0), arm="ready", head_dy=-1),
        dict(breath=1, leg_l=(0, 0), leg_r=(0, 0), arm="ready"),
    ]
    anims["idle"] = []
    for spec in idle_specs:
        im = new_frame()
        draw_pirate(im, **spec)
        anims["idle"].append(im)

    # Walk 6
    walk_legs = [
        ((0, 0), (0, 0)),
        ((-3, 0), (3, -1)),
        ((-4, 1), (4, -1)),
        ((-1, 0), (1, 0)),
        ((3, -1), (-3, 0)),
        ((4, -1), (-4, 1)),
    ]
    anims["walk"] = []
    for i, (ll, rr) in enumerate(walk_legs):
        im = new_frame()
        draw_pirate(im, breath=i % 2, leg_l=ll, leg_r=rr, arm="walk", lean=0)
        anims["walk"].append(im)

    # Attack 8
    atk = [
        dict(arm="windup", lean=-1, head_dy=0),
        dict(arm="anticipation", lean=-2, head_dy=-1),
        dict(arm="swing_start", lean=0, head_dy=0),
        dict(arm="slash", lean=3, head_dy=0),
        dict(arm="impact", lean=4, head_dy=1),
        dict(arm="follow", lean=2, head_dy=0),
        dict(arm="recover", lean=1, head_dy=0),
        dict(arm="return", lean=0, head_dy=0),
    ]
    anims["attack"] = []
    for spec in atk:
        im = new_frame()
        draw_pirate(im, leg_l=(-1, 0), leg_r=(1, 0), **spec)
        anims["attack"].append(im)

    # Hit 3
    hit_specs = [
        dict(arm="hit", lean=-2, hurt=1, head_dy=0),
        dict(arm="hit", lean=-5, hurt=2, head_dy=1),
        dict(arm="hit", lean=-3, hurt=1, head_dy=0),
    ]
    anims["hit"] = []
    for spec in hit_specs:
        im = new_frame()
        draw_pirate(im, **spec)
        anims["hit"].append(im)

    # Victory 4
    vic = [
        dict(arm="victory", smile=0, head_dy=0, lean=0),
        dict(arm="victory", smile=1, head_dy=-1, lean=0),
        dict(arm="victory", smile=2, head_dy=-2, lean=1),
        dict(arm="victory", smile=1, head_dy=-1, lean=0),
    ]
    anims["victory"] = []
    for spec in vic:
        im = new_frame()
        draw_pirate(im, breath=spec["smile"], **spec)
        anims["victory"].append(im)

    return anims


def compose_sheet(anims: dict[str, list[Image.Image]]) -> tuple[Image.Image, dict]:
    order = ["idle", "walk", "attack", "hit", "victory"]
    sheet = Image.new("RGBA", (COLS * FRAME, ROWS * FRAME), (0, 0, 0, 0))
    mapping = {
        "meta": {
            "game": "Libation Warriors",
            "character": "Brine — Pirate Warrior",
            "facing": "right",
            "source_faces_right": True,
            "frame_size": [FRAME, FRAME],
            "sheet_size": [COLS * FRAME, ROWS * FRAME],
            "columns": COLS,
            "rows": ROWS,
            "layout": "Each animation occupies one row; frames left-to-right.",
            "pivot": {"x": PIVOT_X, "y": PIVOT_Y},
            "notes": "Original design. Tricorn, sea-blue coat, burgundy vest, cutlass, flask charm.",
        },
        "animations": {},
        "timings_seconds_per_frame": {
            "idle": 0.18,
            "walk": 0.10,
            "attack": 0.07,
            "hit": 0.08,
            "victory": 0.14,
        },
        "godot_animation_speed_fps": {
            "idle": 5.5,
            "walk": 10.0,
            "attack": 14.0,
            "hit": 12.0,
            "victory": 7.0,
        },
    }
    for row, name in enumerate(order):
        frames = anims[name]
        start = row * COLS
        for col, fr in enumerate(frames):
            sheet.paste(fr, (col * FRAME, row * FRAME), fr)
        end = start + len(frames) - 1
        mapping["animations"][name] = {
            "row": row,
            "frames": len(frames),
            "frame_range": [start, end],
            "frame_indices": list(range(start, end + 1)),
            "cells": [[col, row] for col in range(len(frames))],
            "loop": name in ("idle", "walk"),
        }
    return sheet, mapping


def flip_sheet_h(sheet: Image.Image) -> Image.Image:
    out = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    for row in range(ROWS):
        for col in range(COLS):
            cell = sheet.crop((col * FRAME, row * FRAME, (col + 1) * FRAME, (row + 1) * FRAME))
            if cell.getbbox() is None:
                continue
            flipped = cell.transpose(Image.FLIP_LEFT_RIGHT)
            out.paste(flipped, (col * FRAME, row * FRAME), flipped)
    return out


def write_godot_files() -> None:
    SCRIPTS_DIR.mkdir(parents=True, exist_ok=True)
    (SCRIPTS_DIR / "libation_pirate_frames.gd").write_text(
        '''extends RefCounted
class_name LibationPirateFrames
## Original Libation Warriors pirate ("Brine") — 64x64 sheet.
## Source art faces RIGHT. Use flip_h for left.


const SHEET_PATH := "res://assets/sprites/libation_warriors/pirate_brine_sheet.png"
const FRAME := 64

const ANIM := {
	"idle": {"row": 0, "frames": 4, "speed": 5.5, "loop": true},
	"walk": {"row": 1, "frames": 6, "speed": 10.0, "loop": true},
	"attack": {"row": 2, "frames": 8, "speed": 14.0, "loop": false},
	"hit": {"row": 3, "frames": 3, "speed": 12.0, "loop": false},
	"victory": {"row": 4, "frames": 4, "speed": 7.0, "loop": false},
}

const SOURCE_FACES_RIGHT := true


static func build_sprite_frames() -> SpriteFrames:
	var tex: Texture2D = load(SHEET_PATH)
	var frames := SpriteFrames.new()
	if tex == null:
		push_error("LibationPirateFrames: missing %s" % SHEET_PATH)
		return frames
	for anim_name in ANIM.keys():
		var info: Dictionary = ANIM[anim_name]
		if frames.has_animation(anim_name):
			frames.remove_animation(anim_name)
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, float(info["speed"]))
		frames.set_animation_loop(anim_name, bool(info["loop"]))
		var row: int = int(info["row"])
		for col in range(int(info["frames"])):
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(col * FRAME, row * FRAME, FRAME, FRAME)
			frames.add_frame(anim_name, atlas, 1.0)
	return frames


static func apply_facing(sprite: AnimatedSprite2D, facing_right: bool) -> void:
	sprite.flip_h = SOURCE_FACES_RIGHT != facing_right
	sprite.scale = Vector2(absf(sprite.scale.x), absf(sprite.scale.y))
'''
    )

    # Minimal preview scene script
    (ROOT / "scripts" / "libation_pirate_preview.gd").write_text(
        '''extends Node2D
## Preview Brine pirate animations. Arrow keys change anim, A/D flip facing.

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var label: Label = $Label

var _anims := ["idle", "walk", "attack", "hit", "victory"]
var _idx := 0
var facing_right := true


func _ready() -> void:
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.sprite_frames = LibationPirateFrames.build_sprite_frames()
	_play_current()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and event.keycode == KEY_D):
		facing_right = true
		LibationPirateFrames.apply_facing(sprite, facing_right)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and event.keycode == KEY_A):
		facing_right = false
		LibationPirateFrames.apply_facing(sprite, facing_right)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_idx = (_idx + 1) % _anims.size()
		_play_current()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_idx = (_idx - 1) % _anims.size()
		_play_current()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_play_current()
		get_viewport().set_input_as_handled()


func _play_current() -> void:
	var name := _anims[_idx]
	LibationPirateFrames.apply_facing(sprite, facing_right)
	sprite.play(name)
	label.text = "%s | facing_right=%s flip_h=%s\\nUp/Down: anim  A/D: face  Space: replay" % [
		name, facing_right, sprite.flip_h
	]
'''
    )

    (ROOT / "scenes" / "LibationPiratePreview.tscn").write_text(
        '''[gd_scene load_steps=2 format=3 uid="uid://libationpirateprev001"]

[ext_resource type="Script" path="res://scripts/libation_pirate_preview.gd" id="1_script"]

[node name="LibationPiratePreview" type="Node2D"]
script = ExtResource("1_script")

[node name="Camera2D" type="Camera2D" parent="."]
enabled = true
zoom = Vector2(4, 4)

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
texture_filter = 0
centered = true

[node name="Label" type="Label" parent="."]
offset_left = -120.0
offset_top = -80.0
offset_right = 120.0
offset_bottom = -40.0
theme_override_font_sizes/font_size = 8
text = "Brine"
horizontal_alignment = 1
'''
    )


def write_import_hint(path: Path) -> None:
    """Godot will regenerate .import; provide a sensible starter."""
    rel = path.relative_to(ROOT).as_posix()
    text = f'''[gd_resource type="CompressedTexture2D" loader="CompressedTexture2Loader" format=3]

[resource]
load_path = "res://.godot/imported/{path.name}-placeholder.ctex"
'''
    # Prefer letting Godot create proper .import; write README note instead.
    _ = rel, text


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)

    anims = build_animations()
    sheet, mapping = compose_sheet(anims)

    sheet_path = OUT_DIR / "pirate_brine_sheet.png"
    left_path = OUT_DIR / "pirate_brine_sheet_left.png"
    json_path = OUT_DIR / "pirate_brine_sheet.json"

    sheet.save(sheet_path)
    left = flip_sheet_h(sheet)
    left.save(left_path)
    preview = sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
    preview.save(OUT_DIR / "pirate_brine_sheet_preview_x2.png")

    sheet.save(ARTIFACT_DIR / "pirate_brine_sheet.png")
    left.save(ARTIFACT_DIR / "pirate_brine_sheet_left.png")
    preview.save(ARTIFACT_DIR / "pirate_brine_sheet_preview_x2.png")

    for name, frames in anims.items():
        strip = Image.new("RGBA", (FRAME * len(frames), FRAME), (0, 0, 0, 0))
        for i, fr in enumerate(frames):
            strip.paste(fr, (i * FRAME, 0), fr)
        strip.resize((strip.width * 4, strip.height * 4), Image.NEAREST).save(
            ARTIFACT_DIR / f"pirate_brine_{name}_x4.png"
        )

    mapping["files"] = {
        "sheet_right": "pirate_brine_sheet.png",
        "sheet_left": "pirate_brine_sheet_left.png",
        "preview_x2": "pirate_brine_sheet_preview_x2.png",
        "json": "pirate_brine_sheet.json",
    }
    json_path.write_text(json.dumps(mapping, indent=2) + "\n")
    (ARTIFACT_DIR / "pirate_brine_sheet.json").write_text(json.dumps(mapping, indent=2) + "\n")

    (OUT_DIR / "README.md").write_text(
        """# Libation Warriors — Pirate Warrior (“Brine”)

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
"""
    )

    write_godot_files()

    # Transparency sanity check
    sample = sheet.getpixel((0, 0))
    opaque = sum(1 for p in sheet.getdata() if p[3] > 0)
    print("sheet", sheet_path, sheet.size, "corner_alpha", sample[3], "opaque_px", opaque)
    for name, frames in anims.items():
        print(f"  {name}: {len(frames)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
