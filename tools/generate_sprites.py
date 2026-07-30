#!/usr/bin/env python3
"""
Chrono Trigger / SNES RPG-style 16-bit warrior sprites.

References: Crono-like 3/4 view, multi-shade hair/cloth, scarf/bandana,
belt buckle, boots with highlights, sword at side. ~48x64 canvas.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "assets" / "sprites"
W, H = 48, 64
PREVIEW = 4
T = (0, 0, 0, 0)

# Each faction: outline, skin shades, hair shades, cloth A/B/C, accent, metal, scarf
FACTIONS = {
    "pirate": dict(
        o=(28, 18, 22), sk=(240, 196, 156), sk2=(208, 152, 112), sk3=(168, 112, 80),
        h=(48, 36, 40), h2=(28, 22, 26), h3=(72, 56, 60),
        c=(48, 72, 128), c2=(32, 48, 92), c3=(72, 100, 160),
        a=(196, 48, 56), a2=(148, 32, 40), scarf=(196, 48, 56),
        band=(196, 48, 56), metal=(196, 196, 208), metal2=(140, 140, 156),
        boot=(56, 40, 36), boot2=(36, 24, 22),
    ),
    "militiaman": dict(
        o=(28, 22, 16), sk=(232, 188, 148), sk2=(196, 144, 104), sk3=(156, 108, 76),
        h=(96, 64, 36), h2=(68, 44, 24), h3=(124, 88, 52),
        c=(72, 108, 56), c2=(48, 76, 36), c3=(96, 140, 76),
        a=(196, 160, 64), a2=(148, 116, 40), scarf=(132, 96, 52),
        band=(72, 108, 56), metal=(176, 176, 184), metal2=(124, 124, 132),
        boot=(72, 48, 32), boot2=(48, 32, 20),
    ),
    "bandit": dict(
        o=(24, 16, 14), sk=(216, 164, 124), sk2=(176, 124, 88), sk3=(140, 92, 64),
        h=(52, 36, 28), h2=(32, 22, 18), h3=(72, 52, 40),
        c=(104, 64, 44), c2=(72, 44, 28), c3=(132, 88, 60),
        a=(184, 128, 56), a2=(140, 92, 36), scarf=(56, 48, 44),
        band=(56, 48, 44), metal=(184, 176, 152), metal2=(132, 124, 108),
        boot=(48, 36, 28), boot2=(32, 24, 18),
    ),
    "druid": dict(
        o=(24, 36, 20), sk=(224, 184, 148), sk2=(184, 140, 104), sk3=(148, 108, 76),
        h=(108, 80, 44), h2=(76, 56, 28), h3=(140, 108, 64),
        c=(52, 108, 64), c2=(36, 76, 44), c3=(76, 148, 92),
        a=(108, 176, 72), a2=(76, 132, 48), scarf=(108, 72, 40),
        band=(76, 148, 92), metal=(152, 120, 64), metal2=(108, 84, 40),
        boot=(72, 52, 32), boot2=(48, 36, 20),
    ),
    "barbarian": dict(
        o=(40, 28, 20), sk=(240, 196, 156), sk2=(204, 152, 112), sk3=(164, 116, 80),
        h=(212, 156, 72), h2=(168, 116, 48), h3=(236, 188, 104),
        c=(116, 72, 48), c2=(84, 48, 32), c3=(148, 100, 68),
        a=(176, 52, 44), a2=(128, 36, 28), scarf=(176, 176, 184),
        band=(212, 156, 72), metal=(196, 196, 204), metal2=(140, 140, 148),
        boot=(64, 44, 32), boot2=(44, 28, 20),
    ),
    "paladin": dict(
        o=(40, 36, 52), sk=(240, 200, 164), sk2=(204, 156, 120), sk3=(164, 120, 88),
        h=(108, 80, 48), h2=(76, 56, 32), h3=(140, 108, 68),
        c=(212, 200, 168), c2=(164, 152, 124), c3=(236, 224, 196),
        a=(72, 96, 176), a2=(48, 64, 132), scarf=(72, 96, 176),
        band=(224, 180, 56), metal=(236, 228, 196), metal2=(176, 168, 140),
        boot=(72, 64, 80), boot2=(48, 44, 56),
    ),
    "alchemist": dict(
        o=(36, 40, 44), sk=(228, 188, 152), sk2=(188, 144, 108), sk3=(148, 108, 80),
        h=(60, 64, 68), h2=(40, 44, 48), h3=(84, 88, 92),
        c=(56, 116, 124), c2=(36, 84, 92), c3=(80, 148, 156),
        a=(72, 212, 128), a2=(48, 160, 92), scarf=(196, 184, 156),
        band=(56, 116, 124), metal=(140, 220, 180), metal2=(96, 164, 132),
        boot=(52, 48, 44), boot2=(36, 32, 28),
    ),
    "bard": dict(
        o=(44, 32, 48), sk=(236, 192, 160), sk2=(196, 148, 116), sk3=(156, 112, 84),
        h=(148, 72, 48), h2=(108, 48, 32), h3=(180, 100, 68),
        c=(164, 60, 116), c2=(120, 40, 84), c3=(196, 92, 148),
        a=(236, 188, 72), a2=(180, 140, 48), scarf=(236, 188, 72),
        band=(164, 60, 116), metal=(212, 168, 88), metal2=(156, 120, 56),
        boot=(72, 48, 56), boot2=(48, 32, 40),
    ),
    "red_mage": dict(
        o=(52, 20, 28), sk=(232, 184, 148), sk2=(192, 140, 108), sk3=(152, 104, 76),
        h=(72, 32, 36), h2=(48, 20, 24), h3=(100, 48, 52),
        c=(196, 44, 52), c2=(144, 28, 36), c3=(224, 80, 88),
        a=(240, 208, 176), a2=(188, 156, 128), scarf=(240, 208, 176),
        band=(196, 44, 52), metal=(232, 168, 64), metal2=(176, 120, 40),
        boot=(72, 32, 36), boot2=(48, 20, 24),
    ),
    "white_mage": dict(
        o=(52, 52, 72), sk=(244, 208, 176), sk2=(208, 168, 132), sk3=(168, 128, 96),
        h=(220, 208, 184), h2=(180, 168, 144), h3=(240, 232, 212),
        c=(248, 248, 252), c2=(196, 196, 216), c3=(255, 255, 255),
        a=(184, 196, 232), a2=(140, 152, 196), scarf=(248, 220, 96),
        band=(248, 248, 252), metal=(248, 232, 160), metal2=(196, 176, 108),
        boot=(140, 140, 164), boot2=(100, 100, 124),
    ),
    "black_mage": dict(
        o=(20, 14, 32), sk=(216, 172, 140), sk2=(172, 128, 100), sk3=(132, 96, 72),
        h=(32, 24, 44), h2=(16, 12, 28), h3=(52, 40, 68),
        c=(40, 32, 60), c2=(24, 18, 40), c3=(64, 52, 92),
        a=(120, 56, 168), a2=(84, 36, 124), scarf=(120, 56, 168),
        band=(40, 32, 60), metal=(176, 104, 228), metal2=(124, 68, 168),
        boot=(28, 22, 40), boot2=(16, 12, 28),
    ),
    "brawler": dict(
        o=(36, 28, 24), sk=(228, 180, 140), sk2=(188, 136, 100), sk3=(148, 100, 72),
        h=(56, 44, 40), h2=(36, 28, 24), h3=(80, 64, 56),
        c=(52, 56, 80), c2=(36, 40, 56), c3=(76, 84, 112),
        a=(176, 52, 48), a2=(128, 36, 32), scarf=(176, 52, 48),
        band=(52, 56, 80), metal=(228, 188, 152), metal2=(172, 140, 108),
        boot=(48, 40, 48), boot2=(32, 28, 32),
    ),
    "samurai": dict(
        o=(32, 28, 40), sk=(236, 196, 164), sk2=(196, 152, 120), sk3=(156, 116, 88),
        h=(28, 28, 36), h2=(16, 16, 24), h3=(48, 48, 56),
        c=(44, 48, 64), c2=(28, 32, 44), c3=(68, 72, 92),
        a=(184, 44, 52), a2=(132, 28, 36), scarf=(184, 44, 52),
        band=(44, 48, 64), metal=(212, 212, 224), metal2=(156, 156, 172),
        boot=(36, 36, 44), boot2=(24, 24, 32),
    ),
    "viking": dict(
        o=(32, 28, 24), sk=(232, 184, 144), sk2=(192, 140, 104), sk3=(152, 104, 76),
        h=(228, 220, 212), h2=(180, 172, 164), h3=(248, 244, 236),
        c=(76, 92, 116), c2=(52, 64, 84), c3=(104, 124, 152),
        a=(204, 176, 72), a2=(152, 128, 48), scarf=(148, 104, 56),
        band=(76, 92, 116), metal=(188, 188, 196), metal2=(132, 132, 140),
        boot=(64, 48, 36), boot2=(44, 32, 24),
    ),
    "rogue": dict(
        o=(20, 28, 28), sk=(220, 172, 136), sk2=(176, 128, 96), sk3=(136, 96, 72),
        h=(40, 52, 48), h2=(24, 36, 32), h3=(60, 76, 68),
        c=(48, 64, 56), c2=(32, 44, 40), c3=(72, 92, 80),
        a=(136, 156, 88), a2=(96, 116, 60), scarf=(48, 64, 56),
        band=(48, 64, 56), metal=(172, 176, 184), metal2=(120, 124, 132),
        boot=(32, 40, 36), boot2=(20, 28, 24),
    ),
    "nimrod": dict(
        o=(60, 72, 48), sk=(244, 212, 180), sk2=(208, 168, 132), sk3=(168, 128, 96),
        h=(124, 96, 60), h2=(88, 68, 40), h3=(160, 128, 84),
        c=(128, 176, 96), c2=(92, 136, 64), c3=(164, 208, 128),
        a=(248, 208, 80), a2=(196, 160, 48), scarf=(216, 228, 168),
        band=(128, 176, 96), metal=(180, 156, 100), metal2=(132, 112, 68),
        boot=(88, 100, 64), boot2=(60, 72, 44),
    ),
}


def px(d, x, y, c, w=1, h=1):
    if c is None or (isinstance(c, tuple) and len(c) > 3 and c[3] == 0):
        return
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)


def put(img: Image.Image, x: int, y: int, c):
    if 0 <= x < W and 0 <= y < H and c and (len(c) < 4 or c[3] > 0):
        img.putpixel((x, y), c if len(c) == 4 else (*c, 255))


def draw_crono_body(img: Image.Image, pal: dict, bob: int = 0, swing: int = 0):
    """
    Three-quarter view facing LEFT (Crono-like), light from upper-left.
    Multi-tone shading on hair, cloth, boots.
    """
    d = ImageDraw.Draw(img)
    o, sk, sk2, sk3 = pal["o"], pal["sk"], pal["sk2"], pal["sk3"]
    h, h2, h3 = pal["h"], pal["h2"], pal["h3"]
    c, c2, c3 = pal["c"], pal["c2"], pal["c3"]
    scarf, scarf2 = pal["scarf"], pal.get("a2", pal["scarf"])
    band = pal["band"]
    metal, metal2 = pal["metal"], pal["metal2"]
    boot, boot2 = pal["boot"], pal["boot2"]
    a, a2 = pal["a"], pal["a2"]
    y0 = bob

    # --- Shadow ---
    for i, alpha in enumerate([50, 80, 50]):
        px(d, 14 + i, 60 + y0, (0, 0, 0, alpha), 18 - i * 2, 2)

    # --- Boots (3/4, left foot forward-ish) ---
    # Back boot (right)
    px(d, 26, 52 + y0, o, 10, 7)
    px(d, 27, 53 + y0, boot, 8, 5)
    px(d, 27, 53 + y0, boot2, 8, 2)
    px(d, 28, 56 + y0, a, 6, 1)
    # Front boot (left)
    px(d, 12, 53 + y0, o, 12, 7)
    px(d, 13, 54 + y0, boot, 10, 5)
    px(d, 13, 54 + y0, boot2, 10, 2)
    px(d, 14, 57 + y0, metal2, 5, 1)
    px(d, 15, 55 + y0, a, 3, 1)  # highlight

    # --- Legs / pants ---
    px(d, 16, 42 + y0, o, 7, 12)
    px(d, 17, 42 + y0, c, 5, 11)
    px(d, 17, 42 + y0, c3, 2, 4)  # highlight
    px(d, 19, 48 + y0, c2, 3, 5)
    px(d, 25, 42 + y0, o, 7, 11)
    px(d, 26, 42 + y0, c2, 5, 10)
    px(d, 26, 42 + y0, c, 2, 3)
    # Knee pads
    px(d, 17, 48 + y0, metal, 5, 3)
    px(d, 18, 48 + y0, metal2, 3, 1)
    px(d, 26, 47 + y0, metal, 5, 3)

    # --- Torso ---
    px(d, 14, 26 + y0, o, 20, 17)
    px(d, 15, 27 + y0, c, 18, 15)
    px(d, 15, 27 + y0, c3, 6, 5)   # lit shoulder
    px(d, 27, 28 + y0, c2, 5, 12)  # shadowed side
    px(d, 16, 32 + y0, c2, 16, 2)  # fold
    # Belt
    px(d, 15, 38 + y0, o, 18, 4)
    px(d, 16, 39 + y0, boot, 16, 2)
    px(d, 21, 38 + y0, metal, 5, 4)  # buckle
    px(d, 22, 39 + y0, metal2, 3, 2)
    px(d, 23, 39 + y0, (255, 255, 230), 1, 1)

    # --- Scarf / cowl (volume like Crono) ---
    px(d, 13, 22 + y0, o, 22, 8)
    px(d, 14, 23 + y0, scarf, 20, 6)
    px(d, 14, 23 + y0, a, 8, 3)
    px(d, 26, 24 + y0, scarf2, 7, 4)
    px(d, 18, 26 + y0, scarf2, 10, 2)
    # Scarf tails
    px(d, 30, 28 + y0, o, 5, 10)
    px(d, 31, 28 + y0, scarf, 3, 9)
    px(d, 31, 28 + y0, a, 2, 3)

    # --- Arms ---
    # Back arm (right, holds weapon)
    px(d, 32 + swing, 28 + y0, o, 6, 12)
    px(d, 33 + swing, 29 + y0, sk, 4, 10)
    px(d, 33 + swing, 29 + y0, sk2, 4, 3)
    px(d, 34 + swing, 35 + y0, sk3, 3, 3)
    # Glove
    px(d, 32 + swing, 38 + y0, o, 7, 5)
    px(d, 33 + swing, 39 + y0, boot, 5, 3)
    px(d, 34 + swing, 39 + y0, a, 2, 1)
    # Front arm (left, closer)
    px(d, 10, 28 + y0, o, 6, 13)
    px(d, 11, 29 + y0, sk, 4, 11)
    px(d, 11, 29 + y0, sk3, 1, 4)  # edge shade
    px(d, 12, 29 + y0, (255, 230, 200), 1, 3)  # rim light
    px(d, 10, 39 + y0, o, 7, 5)
    px(d, 11, 40 + y0, boot, 5, 3)
    # Shoulder pads
    px(d, 12, 26 + y0, o, 6, 4)
    px(d, 13, 26 + y0, metal, 4, 3)
    px(d, 30, 26 + y0, o, 6, 4)
    px(d, 31, 26 + y0, metal2, 4, 3)

    # --- Head (3/4) ---
    px(d, 15, 8 + y0, o, 18, 16)
    # Face fill with cheek shade
    for yy in range(9, 23):
        for xx in range(16, 32):
            put(img, xx, yy + y0, sk)
    # Left (lit) cheek highlight / right shade
    for yy in range(14, 22):
        put(img, 17, yy + y0, sk3 if yy > 17 else sk)
        put(img, 30, yy + y0, sk2)
        put(img, 31, yy + y0, sk3)
    px(d, 18, 12 + y0, (255, 235, 210), 4, 2)
    # Eyes (simple CT dots, 3/4 spaced)
    px(d, 20, 15 + y0, o, 2, 3)
    px(d, 26, 15 + y0, o, 2, 3)
    put(img, 20, 15 + y0, (255, 255, 255, 255))
    put(img, 26, 15 + y0, (255, 255, 255, 255))
    # Nose hint
    put(img, 24, 18 + y0, sk2)
    # Mouth
    px(d, 22, 20 + y0, o, 3, 1)

    # --- Spiky hair volume (CT style) ---
    spikes = [
        (18, 4), (21, 2), (24, 1), (27, 2), (30, 4), (32, 6),
        (16, 6), (14, 8), (33, 9), (15, 10),
    ]
    for sx, sy in spikes:
        px(d, sx, sy + y0, o, 3, 5)
        px(d, sx + 1, sy + 1 + y0, h, 2, 4)
        put(img, sx + 1, sy + 1 + y0, h3)
    # Hair mass
    px(d, 16, 6 + y0, o, 18, 8)
    px(d, 17, 7 + y0, h, 16, 6)
    px(d, 17, 7 + y0, h3, 6, 3)
    px(d, 26, 8 + y0, h2, 6, 5)
    # Sideburns / back hair
    px(d, 14, 10 + y0, h2, 3, 10)
    px(d, 31, 10 + y0, h, 3, 8)

    # --- Bandana / headband ---
    px(d, 15, 10 + y0, o, 20, 4)
    px(d, 16, 10 + y0, band, 18, 3)
    px(d, 16, 10 + y0, a, 6, 2)
    px(d, 28, 11 + y0, a2, 5, 2)
    # Knot on side
    px(d, 33, 10 + y0, o, 5, 4)
    px(d, 34, 10 + y0, band, 3, 3)
    px(d, 35, 12 + y0, a, 3, 2)

    # --- Weapon (sword down at right side) ---
    wx = 36 + swing
    px(d, wx, 34 + y0, o, 3, 18)
    px(d, wx + 1, 34 + y0, metal, 1, 16)
    put(img, wx + 1, 35 + y0, (255, 255, 255, 255))
    px(d, wx - 2, 32 + y0, o, 7, 4)
    px(d, wx - 1, 33 + y0, boot, 5, 2)
    px(d, wx, 48 + y0, metal2, 2, 2)


def decorate_faction(img: Image.Image, faction: str, pal: dict, bob: int = 0, swing: int = 0):
    d = ImageDraw.Draw(img)
    y0 = bob
    o, a, metal, c = pal["o"], pal["a"], pal["metal"], pal["c"]

    if faction == "pirate":
        # Eyepatch over right eye area
        px(d, 25, 14 + y0, o, 5, 4)
        px(d, 26, 15 + y0, pal["boot"], 3, 2)
        px(d, 19, 14 + y0, o, 8, 1)  # strap
        # Cutlass curve tip
        px(d, 37 + swing, 50 + y0, metal, 4, 2)
    elif faction == "militiaman":
        # Cross strap
        for i in range(8):
            put(img, 18 + i, 28 + i // 2 + y0, pal["boot"])
        px(d, 36 + swing, 30 + y0, o, 8, 3)  # musket barrel hint
        px(d, 37 + swing, 31 + y0, metal, 6, 1)
    elif faction == "bandit":
        px(d, 18, 16 + y0, o, 14, 3)
        px(d, 19, 16 + y0, pal["boot"], 12, 2)
    elif faction == "druid":
        # Leaf accents on bandana
        px(d, 20, 8 + y0, a, 3, 2)
        px(d, 28, 7 + y0, a, 3, 3)
        # Staff instead tip gem
        px(d, 36 + swing, 20 + y0, o, 4, 4)
        px(d, 37 + swing, 21 + y0, a, 2, 2)
    elif faction == "barbarian":
        # Fur belt overlay
        px(d, 16, 37 + y0, metal, 16, 3)
        px(d, 17, 37 + y0, (220, 210, 200), 3, 2)
        # Axe head
        px(d, 34 + swing, 30 + y0, o, 8, 7)
        px(d, 35 + swing, 31 + y0, metal, 6, 5)
    elif faction == "paladin":
        # Chest crest
        px(d, 20, 30 + y0, o, 8, 7)
        px(d, 21, 31 + y0, a, 6, 5)
        px(d, 23, 32 + y0, metal, 2, 3)
        # Helm brim suggestion already via band gold
    elif faction == "alchemist":
        px(d, 28, 36 + y0, o, 5, 6)
        px(d, 29, 37 + y0, a, 3, 4)
        put(img, 30, 38 + y0, (200, 255, 220, 255))
    elif faction == "bard":
        # Lute body near hip
        px(d, 8, 36 + y0, o, 8, 10)
        px(d, 9, 37 + y0, metal, 6, 8)
        px(d, 11, 39 + y0, o, 2, 2)
    elif faction in ("red_mage", "white_mage", "black_mage"):
        # Robe flare
        px(d, 13, 40 + y0, o, 22, 12)
        px(d, 14, 41 + y0, c, 20, 10)
        px(d, 14, 41 + y0, pal["c3"], 6, 4)
        px(d, 26, 44 + y0, pal["c2"], 7, 6)
        if faction == "black_mage":
            # Tall hat
            px(d, 16, 0 + y0, o, 16, 10)
            px(d, 17, 0 + y0, c, 14, 9)
            px(d, 20, -1 + max(0, y0), o, 8, 3)
            px(d, 20, max(0, y0), c, 8, 2)
        if faction == "white_mage":
            px(d, 22, 30 + y0, a, 4, 5)
    elif faction == "brawler":
        # Bigger gloves
        px(d, 8, 38 + y0, o, 9, 7)
        px(d, 9, 39 + y0, pal["boot"], 7, 5)
        px(d, 31 + swing, 38 + y0, o, 9, 7)
        px(d, 32 + swing, 39 + y0, pal["boot"], 7, 5)
    elif faction == "samurai":
        # Topknot
        px(d, 22, 0 + y0, o, 6, 6)
        px(d, 23, 0 + y0, pal["h"], 4, 5)
        px(d, 24, 1 + y0, a, 2, 2)
        # Katana longer blade already; wrap
        px(d, 34 + swing, 40 + y0, a, 5, 2)
    elif faction == "viking":
        # Horned helm overlay
        px(d, 14, 6 + y0, o, 20, 6)
        px(d, 15, 6 + y0, metal, 18, 5)
        px(d, 12, 7 + y0, o, 3, 7)
        px(d, 33, 7 + y0, o, 3, 7)
        px(d, 12, 7 + y0, a, 2, 5)
        px(d, 34, 7 + y0, a, 2, 5)
    elif faction == "rogue":
        # Hood shadow over hair top
        px(d, 14, 6 + y0, o, 20, 8)
        px(d, 15, 7 + y0, c, 18, 6)
        px(d, 18, 12 + y0, pal["sk"], 12, 6)
    elif faction == "nimrod":
        # Leaf crown
        px(d, 18, 4 + y0, a, 3, 3)
        px(d, 24, 3 + y0, a, 4, 3)
        px(d, 28, 5 + y0, pal["c"], 3, 2)
        # Canteen
        px(d, 30, 36 + y0, o, 6, 7)
        px(d, 31, 37 + y0, metal, 4, 5)


def make_frame(faction: str, frame: int) -> Image.Image:
    pal = FACTIONS[faction]
    bob = [0, -1, 0, 1][frame % 4]
    swing = [0, 1, 0, -1][frame % 4]
    img = Image.new("RGBA", (W, H), T)
    draw_crono_body(img, pal, bob, swing)
    decorate_faction(img, faction, pal, bob, swing)
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for faction in FACTIONS:
        frames = [make_frame(faction, i) for i in range(4)]
        sheet = Image.new("RGBA", (W * 4, H), T)
        for i, fr in enumerate(frames):
            sheet.paste(fr, (i * W, 0), fr)
        icon = frames[0]
        sheet.save(OUT / f"{faction}_sheet.png")
        icon.save(OUT / f"{faction}.png")
        icon.resize((W * PREVIEW, H * PREVIEW), Image.Resampling.NEAREST).save(
            OUT / f"{faction}_preview.png"
        )
        print("wrote", faction)
    (OUT / "factions.txt").write_text("\n".join(FACTIONS) + "\n")
    # collage
    cols = 4
    cell = 200
    rows = (len(FACTIONS) + cols - 1) // cols
    coll = Image.new("RGBA", (cols * cell, rows * cell), (12, 10, 20, 255))
    for i, f in enumerate(FACTIONS):
        im = Image.open(OUT / f"{f}_preview.png").convert("RGBA")
        x = (i % cols) * cell + (cell - im.width) // 2
        y = (i // cols) * cell + (cell - im.height) // 2
        coll.paste(im, (x, y), im)
    coll.save("/opt/cursor/artifacts/faction_sprites.png")
    print("done")


if __name__ == "__main__":
    main()
