#!/usr/bin/env python3
"""Phase 1: extract six master pirate poses into crisp 64x64 transparent PNGs.

Source: generated SNES-JRPG style reference (original character).
Output is nearest-neighbor quantized pixel art — not a reuse of the rejected sheet.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SRC = Path("/opt/cursor/artifacts/assets/pirate_master_style_ref.png")
OUT = ROOT / "assets" / "sprites" / "libation_warriors" / "pirate"
ART = Path("/opt/cursor/artifacts")

FRAME = 64
TARGET_H = 54  # standing character height in px (50–58)
FOOT_Y = 58  # shared floor baseline inside 64x64
PALETTE_COLORS = 28

NAMES = [
    "pirate_master_idle.png",
    "pirate_attack_anticipation.png",
    "pirate_attack_lunge.png",
    "pirate_attack_swing.png",
    "pirate_attack_impact.png",
    "pirate_attack_followthrough.png",
]

LABELS = [
    "1 READY",
    "2 ANTICIPATION",
    "3 LUNGE",
    "4 MAIN SLASH",
    "5 IMPACT",
    "6 FOLLOW-THROUGH",
]


def key_background(im: Image.Image, bg_rgb=(182, 182, 181), thresh: int = 48) -> Image.Image:
    arr = np.array(im.convert("RGBA"))
    rgb = arr[:, :, :3].astype(np.int16)
    dist = np.abs(rgb - np.array(bg_rgb, dtype=np.int16)).sum(axis=2)
    # Also kill near-white / gray fog and soft AA near bg
    gray = rgb.std(axis=2)
    near_gray = (gray < 12) & (np.abs(rgb.mean(axis=2) - 180) < 35)
    alpha = arr[:, :, 3].copy()
    alpha[dist < thresh] = 0
    alpha[near_gray & (dist < 80)] = 0
    arr[:, :, 3] = alpha
    return Image.fromarray(arr, "RGBA")


def remove_slash_fx(im: Image.Image) -> Image.Image:
    """Drop bright translucent arc/sparkle pixels that are not character body."""
    arr = np.array(im)
    rgb = arr[:, :, :3].astype(np.int16)
    a = arr[:, :, 3]
    bright = rgb.mean(axis=2) > 210
    low_sat = rgb.std(axis=2) < 18
    # Keep gold buckle/blade highlights (higher sat or mid brightness with blue/teal neighbors handled later)
    # Remove pale white slash streaks
    kill = bright & low_sat & (a > 0) & (a < 250)
    # Also remove isolated pale dust near feet if very bright
    kill2 = bright & low_sat & (rgb[:, :, 2] > 200) & (a > 0)
    arr[kill | kill2, 3] = 0
    return Image.fromarray(arr, "RGBA")


def content_bbox(im: Image.Image, pad: int = 1) -> tuple[int, int, int, int]:
    arr = np.array(im)
    ys, xs = np.where(arr[:, :, 3] > 20)
    if len(xs) == 0:
        return (0, 0, im.width - 1, im.height - 1)
    x0, x1 = int(xs.min()) - pad, int(xs.max()) + pad
    y0, y1 = int(ys.min()) - pad, int(ys.max()) + pad
    x0 = max(0, x0)
    y0 = max(0, y0)
    x1 = min(im.width - 1, x1)
    y1 = min(im.height - 1, y1)
    return x0, y0, x1, y1


def quantize_opaque(im: Image.Image, colors: int = PALETTE_COLORS) -> Image.Image:
    """Quantize only opaque pixels; keep transparency hard-edged."""
    arr = np.array(im)
    alpha = arr[:, :, 3]
    # Harden alpha
    hard = np.zeros_like(alpha)
    hard[alpha >= 96] = 255
    arr[:, :, 3] = hard

    opaque = Image.fromarray(arr, "RGBA").convert("RGB").quantize(
        colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE
    )
    opaque_rgba = opaque.convert("RGBA")
    out = np.array(opaque_rgba)
    out[:, :, 3] = hard
    # Clean fringe: opaque pixels with almost-bg gray become transparent
    rgb = out[:, :, :3].astype(np.int16)
    grayness = rgb.std(axis=2)
    mean = rgb.mean(axis=2)
    fringe = (hard > 0) & (grayness < 10) & (np.abs(mean - 182) < 28)
    out[fringe, 3] = 0
    return Image.fromarray(out, "RGBA")


def to_frame(im: Image.Image, target_h: int = TARGET_H, foot_y: int = FOOT_Y) -> Image.Image:
    x0, y0, x1, y1 = content_bbox(im)
    crop = im.crop((x0, y0, x1 + 1, y1 + 1))
    # Scale so content height == target_h (nearest)
    scale = target_h / crop.height
    new_w = max(1, int(round(crop.width * scale)))
    new_h = target_h
    # Cap width so we fit in 64 with a little margin
    if new_w > 60:
        scale = 60 / crop.width
        new_w = 60
        new_h = max(1, int(round(crop.height * scale)))
    scaled = crop.resize((new_w, new_h), Image.NEAREST)

    frame = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    # Align feet to foot_y; center-ish horizontally but bias slightly left so sword extension fits right
    paste_x = (FRAME - new_w) // 2
    # Prefer keeping forward sword in-frame: if wide, shift left
    if new_w > 40:
        paste_x = max(1, FRAME - new_w - 2)
        # but keep body roughly centered: blend
        paste_x = int(round(((FRAME - new_w) // 2) * 0.45 + paste_x * 0.55))
        paste_x = max(1, min(paste_x, FRAME - new_w - 1))
    paste_y = foot_y - new_h + 1
    paste_y = max(0, min(paste_y, FRAME - new_h))
    frame.paste(scaled, (paste_x, paste_y), scaled)
    return frame


def measure(im: Image.Image) -> dict:
    arr = np.array(im)
    ys, xs = np.where(arr[:, :, 3] > 20)
    if len(xs) == 0:
        return {"h": 0, "w": 0, "opaque": 0}
    return {
        "h": int(ys.max() - ys.min() + 1),
        "w": int(xs.max() - xs.min() + 1),
        "opaque": int((arr[:, :, 3] > 20).sum()),
        "y0": int(ys.min()),
        "y1": int(ys.max()),
        "x0": int(xs.min()),
        "x1": int(xs.max()),
    }


def build_preview(frames: list[Image.Image], scale: int = 4) -> Image.Image:
    gap = 8
    cell = FRAME * scale
    w = len(frames) * cell + (len(frames) - 1) * gap + 40
    h = cell + 48
    # Checkerboard to prove transparency (not a game asset bg)
    prev = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = prev.load()
    for y in range(h):
        for x in range(w):
            c = 210 if ((x // 8) + (y // 8)) % 2 == 0 else 180
            px[x, y] = (c, c, c, 255)
    draw = ImageDraw.Draw(prev)
    for i, fr in enumerate(frames):
        big = fr.resize((cell, cell), Image.NEAREST)
        x = 20 + i * (cell + gap)
        y = 28
        prev.paste(big, (x, y), big)
        draw.text((x + 4, 6), LABELS[i], fill=(20, 20, 20, 255))
        # baseline guide
        by = y + FOOT_Y * scale
        draw.line((x, by, x + cell, by), fill=(220, 60, 60, 180), width=1)
    return prev


def extract_panels(src: Image.Image) -> list[Image.Image]:
    w, h = src.size
    edges = [int(round(i * w / 6)) for i in range(7)]
    panels = []
    for i in range(6):
        panels.append(src.crop((edges[i], 0, edges[i + 1], h)))
    return panels


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    ART.mkdir(parents=True, exist_ok=True)
    src = Image.open(SRC).convert("RGBA")
    panels = extract_panels(src)

    # Standing poses (idle/anticipation) use full TARGET_H; crouching poses may be shorter content —
    # we still scale each to a shared foot baseline, allowing crouch to be slightly shorter.
    frames: list[Image.Image] = []
    for i, panel in enumerate(panels):
        im = key_background(panel)
        im = remove_slash_fx(im)
        im = quantize_opaque(im)
        # Idle/anticipation taller target; deep crouch frames keep natural shorter height but same feet
        th = TARGET_H if i in (0, 1) else TARGET_H - (2 if i in (3, 4) else 0)
        # Actually keep consistent visual mass: scale all content so foot-aligned; use same scale
        # based on idle height reference for consistency of character size
        frames.append((im, th))

    # Compute a shared scale from idle panel content height so proportions don't drift
    idle_clear = frames[0][0]
    _x0, y0, _x1, y1 = content_bbox(idle_clear)
    idle_h = y1 - y0 + 1
    shared_scale = TARGET_H / idle_h

    out_frames: list[Image.Image] = []
    for i, (im, _th) in enumerate(frames):
        x0, y0, x1, y1 = content_bbox(im)
        crop = im.crop((x0, y0, x1 + 1, y1 + 1))
        new_w = max(1, int(round(crop.width * shared_scale)))
        new_h = max(1, int(round(crop.height * shared_scale)))
        if new_w > 62:
            s = 62 / crop.width
            new_w = 62
            new_h = max(1, int(round(crop.height * s)))
        scaled = crop.resize((new_w, new_h), Image.NEAREST)
        # Re-harden after scale
        scaled = quantize_opaque(scaled, colors=PALETTE_COLORS)

        frame = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
        paste_x = max(1, (FRAME - new_w) // 2)
        # Bias left for extended-sword frames
        if i >= 3:
            paste_x = max(1, min(paste_x, FRAME - new_w - 1))
            paste_x = max(1, paste_x - 2)
        paste_y = FOOT_Y - new_h + 1
        paste_y = max(0, min(paste_y, FRAME - new_h))
        frame.paste(scaled, (paste_x, paste_y), scaled)
        # Final hard alpha
        a = np.array(frame)
        a[:, :, 3] = np.where(a[:, :, 3] >= 96, 255, 0).astype(np.uint8)
        frame = Image.fromarray(a, "RGBA")
        out_frames.append(frame)

        path = OUT / NAMES[i]
        frame.save(path)
        frame.save(ART / NAMES[i])
        m = measure(frame)
        print(f"{NAMES[i]}: {m} corner_alpha={frame.getpixel((0,0))[3]}")

    preview = build_preview(out_frames, scale=5)
    preview_path = OUT / "pirate_phase1_poses_preview_x5.png"
    preview.save(preview_path)
    preview.save(ART / "pirate_phase1_poses_preview_x5.png")

    # Also save a pure transparent strip (no checker) for review
    strip = Image.new("RGBA", (FRAME * 6 + 5 * 4, FRAME), (0, 0, 0, 0))
    for i, fr in enumerate(out_frames):
        strip.paste(fr, (i * (FRAME + 4), 0), fr)
    strip_big = strip.resize((strip.width * 4, strip.height * 4), Image.NEAREST)
    strip_big.save(OUT / "pirate_phase1_poses_strip_x4.png")
    strip_big.save(ART / "pirate_phase1_poses_strip_x4.png")

    # QA gates
    ok = True
    heights = [measure(f)["h"] for f in out_frames]
    foots = [measure(f)["y1"] for f in out_frames]
    print("heights", heights)
    print("foot_y", foots)
    if any(h < 46 or h > 60 for h in heights):
        print("WARN: height outside preferred band for some poses (crouch may be shorter)")
    if max(foots) - min(foots) > 2:
        print("FAIL: foot baseline jitter", foots)
        ok = False
    # Corner must be transparent
    for f, n in zip(out_frames, NAMES):
        if f.getpixel((0, 0))[3] != 0:
            print("FAIL: non-transparent corner", n)
            ok = False
    # Reject if nearly empty
    for f, n in zip(out_frames, NAMES):
        if measure(f)["opaque"] < 400:
            print("FAIL: too few opaque pixels", n)
            ok = False
    print("QA", "PASS" if ok else "CHECK")
    print("Wrote", OUT)
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
