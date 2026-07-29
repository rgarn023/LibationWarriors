#!/usr/bin/env python3
"""Generate Chrono Trigger / SNES RPG-style 16-bit warrior sprites.

Characters are tall chibi SNES heroes (48x64) with soft multi-tone shading,
black outlines, class-defining silhouettes, and a 4-frame idle sheet.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "assets" / "sprites"
W, H = 48, 64
PREVIEW_SCALE = 3
T = (0, 0, 0, 0)

# SNES-friendly palettes (outline + skin + cloth tones)
FACTIONS = {
    "pirate": {
        "o": (24, 16, 20), "sk": (236, 188, 148), "sk2": (200, 140, 108),
        "p": (40, 64, 112), "p2": (28, 44, 80), "s": (168, 40, 48), "s2": (120, 24, 32),
        "a": (212, 168, 56), "h": (32, 28, 36), "w": (196, 196, 208), "w2": (140, 140, 160),
    },
    "militiaman": {
        "o": (28, 22, 16), "sk": (224, 176, 140), "sk2": (188, 132, 100),
        "p": (72, 104, 56), "p2": (48, 72, 36), "s": (132, 96, 52), "s2": (96, 68, 36),
        "a": (196, 160, 64), "h": (76, 48, 28), "w": (168, 168, 176), "w2": (120, 120, 128),
    },
    "bandit": {
        "o": (20, 14, 12), "sk": (208, 156, 120), "sk2": (168, 116, 88),
        "p": (96, 56, 40), "p2": (64, 36, 28), "s": (48, 44, 40), "s2": (32, 28, 28),
        "a": (176, 120, 48), "h": (40, 28, 24), "w": (184, 176, 152), "w2": (132, 124, 108),
    },
    "druid": {
        "o": (20, 32, 18), "sk": (216, 176, 144), "sk2": (176, 132, 104),
        "p": (48, 96, 56), "p2": (32, 68, 40), "s": (108, 72, 40), "s2": (76, 48, 28),
        "a": (96, 164, 72), "h": (96, 72, 40), "w": (140, 108, 56), "w2": (100, 76, 40),
    },
    "barbarian": {
        "o": (36, 24, 18), "sk": (232, 188, 148), "sk2": (196, 144, 108),
        "p": (100, 60, 44), "p2": (72, 40, 28), "s": (176, 176, 184), "s2": (128, 128, 136),
        "a": (160, 48, 40), "h": (196, 156, 72), "w": (184, 184, 192), "w2": (132, 132, 140),
    },
    "paladin": {
        "o": (36, 32, 48), "sk": (236, 196, 160), "sk2": (200, 152, 120),
        "p": (208, 196, 164), "p2": (156, 144, 116), "s": (64, 88, 168), "s2": (40, 56, 120),
        "a": (224, 180, 56), "h": (96, 72, 40), "w": (232, 220, 188), "w2": (176, 164, 132),
    },
    "alchemist": {
        "o": (32, 36, 40), "sk": (220, 180, 148), "sk2": (180, 136, 108),
        "p": (56, 108, 116), "p2": (36, 76, 84), "s": (188, 176, 152), "s2": (140, 128, 108),
        "a": (72, 212, 120), "h": (52, 56, 60), "w": (120, 208, 160), "w2": (80, 148, 112),
    },
    "bard": {
        "o": (40, 28, 44), "sk": (232, 188, 156), "sk2": (192, 144, 116),
        "p": (152, 56, 108), "p2": (108, 36, 76), "s": (196, 148, 68), "s2": (148, 108, 44),
        "a": (232, 188, 72), "h": (128, 60, 40), "w": (204, 160, 80), "w2": (148, 112, 52),
    },
    "red_mage": {
        "o": (48, 18, 24), "sk": (224, 176, 144), "sk2": (184, 132, 104),
        "p": (184, 40, 48), "p2": (132, 24, 32), "s": (232, 208, 184), "s2": (180, 156, 132),
        "a": (232, 168, 56), "h": (64, 28, 28), "w": (216, 80, 72), "w2": (160, 48, 44),
    },
    "white_mage": {
        "o": (48, 48, 68), "sk": (236, 204, 172), "sk2": (200, 160, 128),
        "p": (248, 248, 252), "p2": (200, 200, 216), "s": (180, 192, 228), "s2": (132, 144, 184),
        "a": (248, 220, 88), "h": (212, 200, 176), "w": (248, 232, 152), "w2": (196, 176, 100),
    },
    "black_mage": {
        "o": (16, 12, 28), "sk": (208, 168, 140), "sk2": (164, 124, 100),
        "p": (36, 28, 56), "p2": (20, 16, 36), "s": (100, 48, 140), "s2": (68, 28, 100),
        "a": (176, 96, 220), "h": (24, 20, 36), "w": (152, 80, 196), "w2": (108, 52, 148),
    },
    "brawler": {
        "o": (32, 24, 20), "sk": (220, 172, 136), "sk2": (180, 128, 100),
        "p": (48, 52, 72), "p2": (32, 36, 52), "s": (160, 48, 44), "s2": (112, 32, 28),
        "a": (216, 168, 56), "h": (48, 36, 32), "w": (220, 184, 152), "w2": (168, 136, 108),
    },
    "samurai": {
        "o": (28, 24, 36), "sk": (232, 192, 160), "sk2": (192, 148, 120),
        "p": (40, 44, 56), "p2": (24, 28, 40), "s": (168, 40, 48), "s2": (120, 24, 32),
        "a": (216, 188, 84), "h": (24, 24, 32), "w": (204, 204, 216), "w2": (148, 148, 164),
    },
    "viking": {
        "o": (28, 24, 20), "sk": (224, 176, 140), "sk2": (184, 132, 100),
        "p": (72, 84, 104), "p2": (48, 56, 72), "s": (140, 96, 52), "s2": (100, 68, 36),
        "a": (196, 172, 68), "h": (220, 212, 204), "w": (176, 176, 184), "w2": (124, 124, 132),
    },
    "rogue": {
        "o": (16, 22, 24), "sk": (212, 168, 136), "sk2": (168, 124, 96),
        "p": (44, 56, 52), "p2": (28, 40, 36), "s": (72, 80, 64), "s2": (48, 56, 44),
        "a": (128, 144, 80), "h": (32, 40, 36), "w": (164, 168, 176), "w2": (116, 120, 128),
    },
    "nimrod": {
        "o": (56, 68, 44), "sk": (240, 208, 176), "sk2": (204, 164, 132),
        "p": (120, 168, 88), "p2": (84, 124, 60), "s": (208, 220, 160), "s2": (160, 172, 116),
        "a": (248, 204, 72), "h": (108, 84, 52), "w": (172, 148, 92), "w2": (124, 104, 64),
    },
}


def new_img() -> Image.Image:
    return Image.new("RGBA", (W, H), T)


def px(d: ImageDraw.ImageDraw, x: int, y: int, c, w: int = 1, h: int = 1) -> None:
    if c is None:
        return
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)


def oval(d, x, y, w, h, c):
    d.ellipse([x, y, x + w - 1, y + h - 1], fill=c)


def draw_ct_body(d, pal, bob=0, arm_swing=0):
    """Chrono Trigger-ish chibi: big head, compact torso, short legs."""
    o, sk, sk2 = pal["o"], pal["sk"], pal["sk2"]
    p, p2, s = pal["p"], pal["p2"], pal["s"]
    # Shadow under feet
    px(d, 16, 60 + bob, (0, 0, 0, 40), 16, 2)
    # Boots / feet
    px(d, 15, 54 + bob, o, 7, 5)
    px(d, 26, 54 + bob, o, 7, 5)
    px(d, 16, 55 + bob, p2, 5, 3)
    px(d, 27, 55 + bob, p2, 5, 3)
    px(d, 16, 57 + bob, s, 5, 1)
    px(d, 27, 57 + bob, s, 5, 1)
    # Legs
    px(d, 17, 46 + bob, o, 5, 9)
    px(d, 26, 46 + bob, o, 5, 9)
    px(d, 18, 46 + bob, p, 3, 8)
    px(d, 27, 46 + bob, p, 3, 8)
    px(d, 18, 50 + bob, p2, 3, 3)
    px(d, 27, 50 + bob, p2, 3, 3)
    # Torso (robe-capable)
    px(d, 14, 30 + bob, o, 20, 17)
    px(d, 15, 31 + bob, p, 18, 15)
    px(d, 15, 31 + bob, p2, 18, 3)  # shoulder shade
    px(d, 16, 38 + bob, pal["a"], 16, 1)  # belt accent line
    px(d, 17, 39 + bob, s, 14, 2)
    # Arms
    Lx = 10 - arm_swing
    Rx = 35 + arm_swing
    px(d, Lx, 32 + bob, o, 5, 12)
    px(d, Rx, 32 + bob, o, 5, 12)
    px(d, Lx + 1, 33 + bob, sk, 3, 10)
    px(d, Rx + 1, 33 + bob, sk, 3, 10)
    px(d, Lx + 1, 40 + bob, sk2, 3, 3)
    px(d, Rx + 1, 40 + bob, sk2, 3, 3)
    # Hands
    px(d, Lx, 43 + bob, o, 5, 4)
    px(d, Rx, 43 + bob, o, 5, 4)
    px(d, Lx + 1, 44 + bob, sk, 3, 2)
    px(d, Rx + 1, 44 + bob, sk, 3, 2)
    # Head (large CT-style)
    px(d, 14, 8 + bob, o, 20, 22)
    oval(d, 15, 9 + bob, 18, 20, sk)
    # Cheek shade
    px(d, 16, 22 + bob, sk2, 3, 3)
    px(d, 29, 22 + bob, sk2, 3, 3)
    # Eyes (expressive SNES)
    px(d, 19, 17 + bob, o, 3, 4)
    px(d, 26, 17 + bob, o, 3, 4)
    px(d, 19, 17 + bob, (255, 255, 255), 2, 2)
    px(d, 26, 17 + bob, (255, 255, 255), 2, 2)
    px(d, 20, 19 + bob, (40, 60, 120), 1, 1)
    px(d, 27, 19 + bob, (40, 60, 120), 1, 1)
    # Mouth
    px(d, 22, 24 + bob, o, 4, 1)


def hair_cap(d, pal, bob, style):
    o, h = pal["o"], pal["h"]
    if style == "bandana":
        px(d, 14, 8 + bob, o, 20, 6)
        px(d, 15, 8 + bob, pal["s"], 18, 4)
        px(d, 33, 10 + bob, pal["s"], 5, 3)
        px(d, 34, 11 + bob, pal["s2"], 3, 2)
    elif style == "tricorn":
        px(d, 12, 6 + bob, o, 24, 8)
        px(d, 13, 6 + bob, pal["p"], 22, 6)
        px(d, 10, 10 + bob, o, 28, 3)
        px(d, 11, 10 + bob, pal["p2"], 26, 2)
        px(d, 22, 5 + bob, pal["a"], 4, 2)
    elif style == "tricorn_small":
        px(d, 13, 5 + bob, o, 22, 8)
        px(d, 14, 5 + bob, pal["p"], 20, 6)
        px(d, 11, 10 + bob, o, 26, 2)
    elif style == "tricorne":
        hair_cap(d, pal, bob, "tricorn")
    elif style == "hat_wide":
        px(d, 12, 5 + bob, o, 24, 8)
        px(d, 13, 5 + bob, pal["p"], 22, 6)
        px(d, 10, 11 + bob, o, 28, 2)
        px(d, 11, 11 + bob, pal["p2"], 26, 1)
    elif style == "hood":
        px(d, 13, 6 + bob, o, 22, 16)
        px(d, 14, 7 + bob, pal["p"], 20, 14)
        px(d, 14, 7 + bob, pal["p2"], 20, 4)
        px(d, 18, 14 + bob, (0, 0, 0, 0), 12, 8)  # face opening handled by redraw? skip
        # re-open face by drawing skin oval hole visually via lighter inset
        px(d, 17, 14 + bob, pal["sk"], 14, 10)
    elif style == "helm":
        px(d, 13, 6 + bob, o, 22, 14)
        px(d, 14, 6 + bob, pal["s"], 20, 12)
        px(d, 14, 6 + bob, pal["s2"], 20, 3)
        px(d, 22, 3 + bob, o, 4, 5)
        px(d, 22, 3 + bob, pal["a"], 4, 4)
        px(d, 16, 14 + bob, o, 16, 2)
    elif style == "long":
        px(d, 14, 7 + bob, o, 20, 8)
        px(d, 15, 7 + bob, h, 18, 6)
        px(d, 12, 12 + bob, h, 4, 14)
        px(d, 32, 12 + bob, h, 4, 14)
        px(d, 13, 20 + bob, pal.get("h", h), 2, 6)
        px(d, 33, 20 + bob, pal.get("h", h), 2, 6)
    elif style == "spiky":
        for i, x in enumerate(range(15, 34, 3)):
            px(d, x, 4 + bob + (i % 2), h, 2, 6)
        px(d, 15, 8 + bob, h, 18, 4)
    elif style == "topknot":
        px(d, 15, 9 + bob, h, 18, 4)
        px(d, 21, 2 + bob, o, 6, 8)
        px(d, 22, 2 + bob, h, 4, 7)
        px(d, 23, 1 + bob, pal["a"], 2, 2)
    elif style == "braids":
        px(d, 15, 7 + bob, h, 18, 6)
        px(d, 12, 12 + bob, h, 4, 16)
        px(d, 32, 12 + bob, h, 4, 16)
        px(d, 13, 24 + bob, pal["a"], 2, 2)
        px(d, 33, 24 + bob, pal["a"], 2, 2)
    elif style == "tall_hat":
        px(d, 14, 0 + bob, o, 20, 14)
        px(d, 15, 0 + bob, pal["p"], 18, 12)
        px(d, 18, -2 + max(0, bob), o, 12, 4)
        px(d, 18, -2 + max(0, bob), pal["p"], 12, 3)
        px(d, 15, 8 + bob, pal["p2"], 18, 3)
    else:
        px(d, 15, 7 + bob, h, 18, 5)


def weapon(d, pal, kind, bob=0, swing=0):
    o, w, w2, a = pal["o"], pal["w"], pal["w2"], pal["a"]
    x = 38 + swing
    if kind == "cutlass":
        px(d, x, 28 + bob, o, 3, 20)
        px(d, x + 1, 28 + bob, w, 1, 18)
        px(d, x - 2, 44 + bob, a, 7, 3)
        px(d, x - 1, 45 + bob, w2, 5, 1)
    elif kind == "musket":
        px(d, x - 2, 24 + bob, o, 12, 3)
        px(d, x - 1, 24 + bob, w, 10, 1)
        px(d, x - 1, 26 + bob, pal["s"], 3, 8)
        px(d, x, 27 + bob, w2, 1, 6)
    elif kind == "dagger":
        px(d, x, 34 + bob, o, 3, 12)
        px(d, x + 1, 34 + bob, w, 1, 10)
        px(d, x - 1, 42 + bob, a, 5, 2)
    elif kind == "staff":
        px(d, x, 12 + bob, o, 3, 34)
        px(d, x + 1, 12 + bob, w, 1, 32)
        px(d, x - 2, 10 + bob, o, 7, 7)
        px(d, x - 1, 11 + bob, a, 5, 5)
        px(d, x, 12 + bob, (255, 255, 200), 3, 3)
    elif kind == "axe":
        px(d, x, 24 + bob, o, 3, 24)
        px(d, x + 1, 24 + bob, w, 1, 22)
        px(d, x - 4, 22 + bob, o, 11, 8)
        px(d, x - 3, 23 + bob, a, 9, 6)
        px(d, x - 2, 24 + bob, w2, 3, 4)
    elif kind == "sword":
        px(d, x, 16 + bob, o, 3, 30)
        px(d, x + 1, 16 + bob, w, 1, 28)
        px(d, x - 3, 40 + bob, a, 9, 3)
        px(d, x - 1, 42 + bob, w2, 5, 2)
    elif kind == "katana":
        px(d, x, 14 + bob, o, 3, 32)
        px(d, x + 1, 14 + bob, w, 1, 30)
        px(d, x - 3, 40 + bob, pal["s"], 9, 3)
        px(d, x - 1, 41 + bob, a, 5, 1)
    elif kind == "flask":
        px(d, x - 1, 36 + bob, o, 7, 10)
        px(d, x, 37 + bob, a, 5, 8)
        px(d, x + 1, 38 + bob, (180, 255, 200), 2, 4)
        px(d, x + 1, 34 + bob, o, 3, 3)
        px(d, x + 1, 34 + bob, w, 3, 2)
    elif kind == "lute":
        px(d, x - 2, 34 + bob, o, 10, 12)
        px(d, x - 1, 35 + bob, w, 8, 10)
        px(d, x + 1, 37 + bob, o, 3, 3)
        px(d, x + 1, 24 + bob, o, 3, 12)
        px(d, x + 1, 24 + bob, a, 2, 10)
    elif kind == "wand":
        px(d, x, 20 + bob, o, 3, 26)
        px(d, x + 1, 20 + bob, w, 1, 24)
        px(d, x - 2, 16 + bob, o, 7, 7)
        px(d, x - 1, 17 + bob, a, 5, 5)
        px(d, x, 18 + bob, (255, 230, 120), 3, 3)
    elif kind == "fists":
        px(d, 8, 44 + bob, o, 7, 6)
        px(d, 33, 44 + bob, o, 7, 6)
        px(d, 9, 45 + bob, pal["sk"], 5, 4)
        px(d, 34, 45 + bob, pal["sk"], 5, 4)
        px(d, 10, 46 + bob, a, 3, 2)
        px(d, 35, 46 + bob, a, 3, 2)
    elif kind == "club":
        px(d, x, 28 + bob, o, 4, 18)
        px(d, x + 1, 28 + bob, w, 2, 16)
        px(d, x - 2, 24 + bob, o, 8, 8)
        px(d, x - 1, 25 + bob, a, 6, 6)


def decorate(d, faction, pal, bob=0, swing=0):
    a, p, s, o = pal["a"], pal["p"], pal["s"], pal["o"]
    if faction == "pirate":
        px(d, 15, 36 + bob, s, 18, 3)
        px(d, 18, 16 + bob, o, 5, 3)  # eyepatch
        px(d, 19, 17 + bob, pal["s2"], 3, 2)
        hair_cap(d, pal, bob, "bandana")
        weapon(d, pal, "cutlass", bob, swing)
    elif faction == "militiaman":
        px(d, 15, 32 + bob, a, 18, 2)
        px(d, 22, 33 + bob, s, 4, 10)
        hair_cap(d, pal, bob, "hat_wide")
        weapon(d, pal, "musket", bob, swing)
    elif faction == "bandit":
        px(d, 17, 18 + bob, o, 14, 4)
        px(d, 18, 18 + bob, s, 12, 3)
        hair_cap(d, pal, bob, "hood")
        weapon(d, pal, "dagger", bob, swing)
    elif faction == "druid":
        px(d, 16, 34 + bob, a, 16, 3)
        px(d, 20, 5 + bob, a, 3, 3)
        px(d, 26, 4 + bob, a, 4, 4)
        hair_cap(d, pal, bob, "long")
        weapon(d, pal, "staff", bob, swing)
    elif faction == "barbarian":
        px(d, 15, 40 + bob, s, 18, 4)
        px(d, 16, 41 + bob, pal["w"], 4, 2)
        hair_cap(d, pal, bob, "spiky")
        weapon(d, pal, "axe", bob, swing)
    elif faction == "paladin":
        px(d, 20, 34 + bob, a, 8, 8)
        px(d, 22, 36 + bob, s, 4, 4)
        hair_cap(d, pal, bob, "helm")
        weapon(d, pal, "sword", bob, swing)
    elif faction == "alchemist":
        px(d, 15, 42 + bob, pal["s"], 18, 5)
        px(d, 30, 36 + bob, a, 4, 4)
        hair_cap(d, pal, bob, "default")
        weapon(d, pal, "flask", bob, swing)
    elif faction == "bard":
        px(d, 15, 32 + bob, a, 18, 2)
        px(d, 16, 34 + bob, s, 16, 10)
        hair_cap(d, pal, bob, "long")
        weapon(d, pal, "lute", bob, swing)
    elif faction == "red_mage":
        px(d, 13, 30 + bob, o, 22, 18)
        px(d, 14, 31 + bob, p, 20, 16)
        px(d, 15, 32 + bob, pal["s"], 18, 3)
        hair_cap(d, pal, bob, "hat_wide")
        weapon(d, pal, "wand", bob, swing)
    elif faction == "white_mage":
        px(d, 13, 30 + bob, o, 22, 18)
        px(d, 14, 31 + bob, p, 20, 16)
        px(d, 22, 36 + bob, a, 4, 6)
        hair_cap(d, pal, bob, "hat_wide")
        weapon(d, pal, "staff", bob, swing)
    elif faction == "black_mage":
        px(d, 13, 30 + bob, o, 22, 18)
        px(d, 14, 31 + bob, p, 20, 16)
        hair_cap(d, pal, bob, "tall_hat")
        weapon(d, pal, "wand", bob, swing)
    elif faction == "brawler":
        px(d, 15, 32 + bob, s, 18, 3)
        hair_cap(d, pal, bob, "spiky")
        weapon(d, pal, "fists", bob, swing)
    elif faction == "samurai":
        px(d, 15, 34 + bob, s, 18, 5)
        px(d, 16, 35 + bob, a, 16, 1)
        hair_cap(d, pal, bob, "topknot")
        weapon(d, pal, "katana", bob, swing)
    elif faction == "viking":
        px(d, 13, 6 + bob, o, 22, 10)
        px(d, 14, 6 + bob, s, 20, 8)
        px(d, 11, 8 + bob, o, 3, 8)
        px(d, 34, 8 + bob, o, 3, 8)
        px(d, 11, 8 + bob, a, 2, 6)
        px(d, 35, 8 + bob, a, 2, 6)
        hair_cap(d, pal, bob, "braids")
        weapon(d, pal, "axe", bob, swing)
    elif faction == "rogue":
        px(d, 17, 16 + bob, o, 14, 5)
        px(d, 18, 16 + bob, p, 12, 4)
        hair_cap(d, pal, bob, "hood")
        weapon(d, pal, "dagger", bob, swing)
    elif faction == "nimrod":
        px(d, 15, 34 + bob, s, 18, 3)
        px(d, 18, 4 + bob, a, 3, 3)
        px(d, 27, 3 + bob, a, 4, 4)
        px(d, 22, 5 + bob, p, 4, 3)
        hair_cap(d, pal, bob, "default")
        weapon(d, pal, "club", bob, swing)


def make_frame(faction: str, frame: int) -> Image.Image:
    pal = FACTIONS[faction]
    bob = [0, -1, 0, 1][frame % 4]
    swing = [0, 1, 0, -1][frame % 4]
    img = new_img()
    d = ImageDraw.Draw(img)
    draw_ct_body(d, pal, bob, swing // 2 if swing else 0)
    decorate(d, faction, pal, bob, swing)
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
        icon.resize((W * PREVIEW_SCALE, H * PREVIEW_SCALE), Image.Resampling.NEAREST).save(
            OUT / f"{faction}_preview.png"
        )
        print("wrote", faction)
    (OUT / "factions.txt").write_text("\n".join(FACTIONS.keys()) + "\n")
    print("done", OUT)


if __name__ == "__main__":
    main()
