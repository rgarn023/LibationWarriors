#!/usr/bin/env python3
"""Generate authentic 16-bit style warrior sprites for Libation Warriors."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "assets" / "sprites"
SIZE = 32
SCALE = 4  # export upscaled nearest-neighbor previews + native 32px sheets

# Transparent
T = (0, 0, 0, 0)

FACTIONS = {
    "pirate": {
        "skin": (232, 190, 150),
        "outline": (28, 20, 18),
        "primary": (45, 70, 110),
        "secondary": (140, 40, 40),
        "accent": (200, 170, 60),
        "hair": (30, 28, 35),
        "weapon": (180, 180, 190),
    },
    "militiaman": {
        "skin": (220, 175, 140),
        "outline": (30, 24, 18),
        "primary": (70, 90, 55),
        "secondary": (120, 90, 50),
        "accent": (180, 150, 70),
        "hair": (70, 45, 25),
        "weapon": (150, 150, 155),
    },
    "bandit": {
        "skin": (200, 155, 120),
        "outline": (25, 18, 15),
        "primary": (90, 55, 40),
        "secondary": (50, 45, 40),
        "accent": (160, 110, 50),
        "hair": (40, 30, 25),
        "weapon": (170, 160, 140),
    },
    "druid": {
        "skin": (210, 175, 145),
        "outline": (25, 35, 20),
        "primary": (50, 90, 55),
        "secondary": (100, 70, 40),
        "accent": (90, 140, 70),
        "hair": (90, 70, 40),
        "weapon": (130, 100, 55),
    },
    "barbarian": {
        "skin": (225, 185, 150),
        "outline": (35, 25, 20),
        "primary": (90, 55, 40),
        "secondary": (160, 160, 165),
        "accent": (140, 50, 40),
        "hair": (180, 150, 80),
        "weapon": (170, 170, 175),
    },
    "paladin": {
        "skin": (230, 195, 160),
        "outline": (40, 35, 50),
        "primary": (200, 190, 160),
        "secondary": (70, 90, 160),
        "accent": (210, 175, 60),
        "hair": (90, 70, 40),
        "weapon": (220, 210, 180),
    },
    "alchemist": {
        "skin": (215, 180, 150),
        "outline": (35, 40, 45),
        "primary": (60, 100, 110),
        "secondary": (180, 170, 150),
        "accent": (80, 200, 120),
        "hair": (50, 55, 60),
        "weapon": (120, 200, 160),
    },
    "bard": {
        "skin": (225, 185, 155),
        "outline": (40, 30, 45),
        "primary": (140, 60, 100),
        "secondary": (180, 140, 70),
        "accent": (220, 180, 80),
        "hair": (120, 60, 40),
        "weapon": (190, 150, 80),
    },
    "red_mage": {
        "skin": (220, 175, 145),
        "outline": (50, 20, 25),
        "primary": (170, 40, 45),
        "secondary": (220, 200, 180),
        "accent": (220, 160, 60),
        "hair": (60, 30, 30),
        "weapon": (200, 80, 70),
    },
    "white_mage": {
        "skin": (230, 200, 170),
        "outline": (50, 50, 70),
        "primary": (240, 240, 245),
        "secondary": (180, 190, 220),
        "accent": (240, 220, 100),
        "hair": (200, 190, 170),
        "weapon": (240, 230, 160),
    },
    "black_mage": {
        "skin": (200, 165, 140),
        "outline": (20, 15, 30),
        "primary": (35, 30, 50),
        "secondary": (90, 50, 120),
        "accent": (160, 90, 200),
        "hair": (25, 20, 35),
        "weapon": (140, 80, 180),
    },
    "brawler": {
        "skin": (215, 170, 135),
        "outline": (35, 25, 20),
        "primary": (50, 55, 70),
        "secondary": (140, 50, 45),
        "accent": (200, 160, 60),
        "hair": (45, 35, 30),
        "weapon": (210, 180, 150),
    },
    "samurai": {
        "skin": (225, 190, 160),
        "outline": (30, 25, 35),
        "primary": (40, 45, 55),
        "secondary": (150, 40, 45),
        "accent": (200, 180, 90),
        "hair": (25, 25, 30),
        "weapon": (190, 190, 200),
    },
    "viking": {
        "skin": (220, 175, 140),
        "outline": (30, 25, 20),
        "primary": (70, 80, 95),
        "secondary": (130, 90, 50),
        "accent": (180, 160, 70),
        "hair": (200, 190, 185),
        "weapon": (160, 160, 165),
    },
    "rogue": {
        "skin": (205, 165, 135),
        "outline": (20, 25, 30),
        "primary": (45, 55, 50),
        "secondary": (70, 75, 60),
        "accent": (120, 130, 80),
        "hair": (35, 40, 35),
        "weapon": (150, 155, 160),
    },
    "nimrod": {
        "skin": (235, 205, 175),
        "outline": (60, 70, 50),
        "primary": (120, 160, 90),
        "secondary": (200, 210, 160),
        "accent": (240, 200, 80),
        "hair": (100, 80, 50),
        "weapon": (160, 140, 90),
    },
}


def new_frame() -> Image.Image:
    return Image.new("RGBA", (SIZE, SIZE), T)


def px(draw: ImageDraw.ImageDraw, x: int, y: int, c, w: int = 1, h: int = 1) -> None:
    if c is None or (isinstance(c, tuple) and len(c) == 4 and c[3] == 0):
        return
    draw.rectangle([x, y, x + w - 1, y + h - 1], fill=c)


def draw_base_body(draw, pal, bob: int = 0) -> None:
    o, sk, p, s = pal["outline"], pal["skin"], pal["primary"], pal["secondary"]
    # Legs
    px(draw, 12, 24 + bob, o, 3, 6)
    px(draw, 17, 24 + bob, o, 3, 6)
    px(draw, 13, 24 + bob, p, 1, 5)
    px(draw, 18, 24 + bob, p, 1, 5)
    # Boots
    px(draw, 11, 29 + bob, o, 4, 2)
    px(draw, 17, 29 + bob, o, 4, 2)
    px(draw, 12, 29 + bob, s, 2, 1)
    px(draw, 18, 29 + bob, s, 2, 1)
    # Torso
    px(draw, 11, 15 + bob, o, 10, 10)
    px(draw, 12, 16 + bob, p, 8, 8)
    # Arms
    px(draw, 8, 16 + bob, o, 3, 7)
    px(draw, 21, 16 + bob, o, 3, 7)
    px(draw, 9, 17 + bob, sk, 1, 5)
    px(draw, 22, 17 + bob, sk, 1, 5)
    # Head
    px(draw, 11, 6 + bob, o, 10, 10)
    px(draw, 12, 7 + bob, sk, 8, 8)
    # Eyes
    px(draw, 14, 10 + bob, o, 2, 2)
    px(draw, 18, 10 + bob, o, 2, 2)
    px(draw, 14, 10 + bob, (255, 255, 255), 1, 1)
    px(draw, 18, 10 + bob, (255, 255, 255), 1, 1)


def add_hair(draw, pal, style: str, bob: int = 0) -> None:
    h, o = pal["hair"], pal["outline"]
    if style == "bandana":
        px(draw, 11, 5 + bob, o, 10, 3)
        px(draw, 12, 5 + bob, pal["secondary"], 8, 2)
        px(draw, 21, 6 + bob, pal["secondary"], 3, 2)
    elif style == "hat":
        px(draw, 10, 4 + bob, o, 12, 4)
        px(draw, 11, 4 + bob, pal["primary"], 10, 3)
        px(draw, 9, 7 + bob, o, 14, 2)
    elif style == "hood":
        px(draw, 10, 5 + bob, o, 12, 8)
        px(draw, 11, 6 + bob, pal["primary"], 10, 6)
    elif style == "helm":
        px(draw, 10, 5 + bob, o, 12, 6)
        px(draw, 11, 5 + bob, pal["secondary"], 10, 5)
        px(draw, 15, 3 + bob, o, 2, 3)
        px(draw, 15, 3 + bob, pal["accent"], 2, 2)
    elif style == "long":
        px(draw, 11, 5 + bob, o, 10, 4)
        px(draw, 12, 5 + bob, h, 8, 3)
        px(draw, 10, 8 + bob, h, 2, 6)
        px(draw, 20, 8 + bob, h, 2, 6)
    elif style == "spiky":
        for x in range(12, 21, 2):
            px(draw, x, 4 + bob, h, 1, 3)
        px(draw, 12, 6 + bob, h, 8, 2)
    elif style == "topknot":
        px(draw, 12, 6 + bob, h, 8, 2)
        px(draw, 15, 2 + bob, o, 2, 4)
        px(draw, 15, 2 + bob, h, 2, 3)
    elif style == "braids":
        px(draw, 12, 5 + bob, h, 8, 3)
        px(draw, 10, 8 + bob, h, 2, 8)
        px(draw, 20, 8 + bob, h, 2, 8)
    else:
        px(draw, 12, 5 + bob, h, 8, 3)


def add_weapon(draw, pal, kind: str, bob: int = 0, swing: int = 0) -> None:
    w, o, a = pal["weapon"], pal["outline"], pal["accent"]
    if kind == "cutlass":
        px(draw, 23 + swing, 14 + bob, o, 2, 10)
        px(draw, 23 + swing, 14 + bob, w, 1, 9)
        px(draw, 22 + swing, 22 + bob, a, 4, 2)
    elif kind == "musket":
        px(draw, 22 + swing, 12 + bob, o, 8, 2)
        px(draw, 22 + swing, 12 + bob, w, 7, 1)
        px(draw, 22 + swing, 14 + bob, pal["secondary"], 2, 4)
    elif kind == "dagger":
        px(draw, 23 + swing, 16 + bob, o, 2, 7)
        px(draw, 23 + swing, 16 + bob, w, 1, 6)
        px(draw, 22 + swing, 21 + bob, a, 3, 1)
    elif kind == "staff":
        px(draw, 23 + swing, 8 + bob, o, 2, 16)
        px(draw, 23 + swing, 8 + bob, w, 1, 15)
        px(draw, 22 + swing, 7 + bob, a, 3, 3)
    elif kind == "axe":
        px(draw, 23 + swing, 12 + bob, o, 2, 12)
        px(draw, 23 + swing, 12 + bob, w, 1, 11)
        px(draw, 21 + swing, 11 + bob, o, 6, 5)
        px(draw, 22 + swing, 12 + bob, a, 4, 3)
    elif kind == "sword":
        px(draw, 23 + swing, 10 + bob, o, 2, 14)
        px(draw, 23 + swing, 10 + bob, w, 1, 13)
        px(draw, 21 + swing, 20 + bob, a, 5, 2)
    elif kind == "flask":
        px(draw, 23 + swing, 18 + bob, o, 4, 5)
        px(draw, 24 + swing, 19 + bob, a, 2, 3)
        px(draw, 24 + swing, 17 + bob, o, 2, 2)
    elif kind == "lute":
        px(draw, 22 + swing, 16 + bob, o, 6, 8)
        px(draw, 23 + swing, 17 + bob, w, 4, 6)
        px(draw, 24 + swing, 12 + bob, o, 2, 5)
        px(draw, 24 + swing, 12 + bob, a, 1, 4)
    elif kind == "wand":
        px(draw, 23 + swing, 12 + bob, o, 2, 12)
        px(draw, 23 + swing, 12 + bob, w, 1, 11)
        px(draw, 22 + swing, 10 + bob, a, 3, 3)
    elif kind == "katana":
        px(draw, 23 + swing, 8 + bob, o, 2, 16)
        px(draw, 23 + swing, 8 + bob, w, 1, 15)
        px(draw, 21 + swing, 20 + bob, pal["secondary"], 5, 2)
    elif kind == "fists":
        px(draw, 7, 22 + bob, o, 4, 3)
        px(draw, 21, 22 + bob, o, 4, 3)
        px(draw, 8, 22 + bob, pal["skin"], 2, 2)
        px(draw, 22, 22 + bob, pal["skin"], 2, 2)
    elif kind == "club":
        px(draw, 23 + swing, 14 + bob, o, 3, 10)
        px(draw, 23 + swing, 14 + bob, w, 2, 9)
        px(draw, 22 + swing, 12 + bob, o, 5, 4)
        px(draw, 23 + swing, 12 + bob, a, 3, 3)


def decorate(draw, faction: str, pal, bob: int = 0) -> None:
    a, p, s, o = pal["accent"], pal["primary"], pal["secondary"], pal["outline"]
    if faction == "pirate":
        px(draw, 12, 16 + bob, s, 8, 2)  # sash
        px(draw, 14, 9 + bob, o, 2, 1)  # eyepatch line
        add_hair(draw, pal, "bandana", bob)
        add_weapon(draw, pal, "cutlass", bob)
    elif faction == "militiaman":
        px(draw, 12, 16 + bob, a, 8, 1)
        px(draw, 15, 17 + bob, s, 2, 4)  # strap
        add_hair(draw, pal, "hat", bob)
        add_weapon(draw, pal, "musket", bob)
    elif faction == "bandit":
        px(draw, 13, 12 + bob, o, 6, 2)  # mask
        px(draw, 13, 12 + bob, s, 6, 1)
        add_hair(draw, pal, "hood", bob)
        add_weapon(draw, pal, "dagger", bob)
    elif faction == "druid":
        px(draw, 12, 16 + bob, a, 8, 2)
        px(draw, 14, 5 + bob, a, 1, 1)  # leaf
        px(draw, 17, 4 + bob, a, 2, 2)
        add_hair(draw, pal, "long", bob)
        add_weapon(draw, pal, "staff", bob)
    elif faction == "barbarian":
        px(draw, 12, 18 + bob, s, 8, 2)  # fur belt
        px(draw, 13, 16 + bob, sk_tone(pal), 2, 2)
        add_hair(draw, pal, "spiky", bob)
        add_weapon(draw, pal, "axe", bob)
    elif faction == "paladin":
        px(draw, 14, 17 + bob, a, 4, 4)  # crest
        px(draw, 15, 18 + bob, s, 2, 2)
        add_hair(draw, pal, "helm", bob)
        add_weapon(draw, pal, "sword", bob)
    elif faction == "alchemist":
        px(draw, 12, 20 + bob, s, 8, 3)  # apron
        px(draw, 19, 15 + bob, a, 2, 2)  # vial on belt
        add_hair(draw, pal, "default", bob)
        add_weapon(draw, pal, "flask", bob)
    elif faction == "bard":
        px(draw, 12, 16 + bob, a, 8, 1)
        px(draw, 13, 17 + bob, s, 6, 5)
        add_hair(draw, pal, "long", bob)
        add_weapon(draw, pal, "lute", bob)
    elif faction == "red_mage":
        px(draw, 10, 14 + bob, o, 12, 10)  # robe widen
        px(draw, 11, 15 + bob, p, 10, 8)
        px(draw, 12, 16 + bob, s, 8, 2)
        add_hair(draw, pal, "hat", bob)
        add_weapon(draw, pal, "wand", bob)
    elif faction == "white_mage":
        px(draw, 10, 14 + bob, o, 12, 10)
        px(draw, 11, 15 + bob, p, 10, 8)
        px(draw, 15, 17 + bob, a, 2, 3)
        add_hair(draw, pal, "hat", bob)
        add_weapon(draw, pal, "staff", bob)
    elif faction == "black_mage":
        px(draw, 10, 14 + bob, o, 12, 10)
        px(draw, 11, 15 + bob, p, 10, 8)
        px(draw, 10, 4 + bob, o, 12, 8)  # tall hat
        px(draw, 11, 4 + bob, p, 10, 7)
        px(draw, 14, 2 + bob, o, 4, 3)
        px(draw, 14, 2 + bob, p, 4, 2)
        add_weapon(draw, pal, "wand", bob)
    elif faction == "brawler":
        px(draw, 12, 16 + bob, s, 8, 2)
        px(draw, 8, 21 + bob, o, 4, 3)
        px(draw, 20, 21 + bob, o, 4, 3)
        add_hair(draw, pal, "spiky", bob)
        add_weapon(draw, pal, "fists", bob)
    elif faction == "samurai":
        px(draw, 12, 16 + bob, s, 8, 3)
        px(draw, 11, 5 + bob, o, 10, 4)
        px(draw, 12, 5 + bob, p, 8, 3)
        add_hair(draw, pal, "topknot", bob)
        add_weapon(draw, pal, "katana", bob)
    elif faction == "viking":
        px(draw, 10, 5 + bob, o, 12, 5)
        px(draw, 11, 5 + bob, s, 10, 4)
        px(draw, 9, 6 + bob, o, 2, 4)  # horn
        px(draw, 21, 6 + bob, o, 2, 4)
        px(draw, 9, 6 + bob, a, 1, 3)
        px(draw, 22, 6 + bob, a, 1, 3)
        add_hair(draw, pal, "braids", bob)
        add_weapon(draw, pal, "axe", bob)
    elif faction == "rogue":
        px(draw, 13, 11 + bob, o, 6, 3)
        px(draw, 13, 11 + bob, p, 6, 2)
        add_hair(draw, pal, "hood", bob)
        add_weapon(draw, pal, "dagger", bob)
    elif faction == "nimrod":
        # Goofy non-alcoholic scout with canteen & leaf crown
        px(draw, 12, 16 + bob, s, 8, 2)
        px(draw, 13, 4 + bob, a, 2, 2)
        px(draw, 17, 3 + bob, a, 2, 2)
        px(draw, 15, 5 + bob, pal["primary"], 2, 2)
        add_hair(draw, pal, "default", bob)
        add_weapon(draw, pal, "club", bob)


def sk_tone(pal):
    return pal["skin"]


def make_sheet(faction: str) -> Image.Image:
    pal = FACTIONS[faction]
    frames = []
    for i, bob in enumerate([0, -1, 0, 1]):
        img = new_frame()
        draw = ImageDraw.Draw(img)
        draw_base_body(draw, pal, bob)
        decorate(draw, faction, pal, bob)
        frames.append(img)
    sheet = Image.new("RGBA", (SIZE * 4, SIZE), T)
    for i, fr in enumerate(frames):
        sheet.paste(fr, (i * SIZE, 0), fr)
    return sheet


def make_icon(faction: str) -> Image.Image:
    pal = FACTIONS[faction]
    img = new_frame()
    draw = ImageDraw.Draw(img)
    draw_base_body(draw, pal, 0)
    decorate(draw, faction, pal, 0)
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    index = []
    for faction in FACTIONS:
        sheet = make_sheet(faction)
        icon = make_icon(faction)
        sheet_path = OUT / f"{faction}_sheet.png"
        icon_path = OUT / f"{faction}.png"
        sheet.save(sheet_path)
        icon.save(icon_path)
        # Also save 4x preview for docs/UI clarity (nearest)
        preview = icon.resize((SIZE * SCALE, SIZE * SCALE), Image.Resampling.NEAREST)
        preview.save(OUT / f"{faction}_preview.png")
        index.append(faction)
        print(f"wrote {faction}")
    (OUT / "factions.txt").write_text("\n".join(index) + "\n")
    print(f"Generated {len(index)} faction sprites in {OUT}")


if __name__ == "__main__":
    main()
