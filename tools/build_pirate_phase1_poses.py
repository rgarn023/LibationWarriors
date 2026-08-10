#!/usr/bin/env python3
"""Build Phase-1 Libation Warriors pirate poses: 64x64 transparent pixel art.

Uses individually generated pose renders (original character), chroma-keys magenta,
locks a shared palette from the master ready pose, nearest-neighbor scales to a
shared foot baseline. Does NOT use the rejected brine sheet.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "sprites" / "libation_warriors" / "pirate"
ART = Path("/opt/cursor/artifacts")
SRC_DIR = ART / "assets"

FRAME = 64
TARGET_H = 56
FOOT_Y = 59
PALETTE_N = 32

POSE_SRCS = [
    ("pirate_pose1_ready.png", "pirate_master_idle.png", "1 READY"),
    ("pirate_pose2_anticipation_v2.png", "pirate_attack_anticipation.png", "2 ANTICIPATION"),
    ("pirate_pose3_lunge.png", "pirate_attack_lunge.png", "3 LUNGE"),
    ("pirate_pose4_swing.png", "pirate_attack_swing.png", "4 MAIN SLASH"),
    ("pirate_pose5_impact_v2.png", "pirate_attack_impact.png", "5 IMPACT"),
    ("pirate_pose6_followthrough.png", "pirate_attack_followthrough.png", "6 FOLLOW-THROUGH"),
]


def chroma_key(im: Image.Image) -> Image.Image:
    arr = np.array(im.convert("RGBA"))
    r = arr[:, :, 0].astype(np.int16)
    g = arr[:, :, 1].astype(np.int16)
    b = arr[:, :, 2].astype(np.int16)
    # Magenta key only — do NOT key gray/cream (shirt/sash highlights).
    magenta = (
        (r > 170)
        & (b > 170)
        & (g < 160)
        & ((r + b) > (2 * g + 30))
        & (np.abs(r - b) < 90)
    )
    alpha = arr[:, :, 3].copy()
    alpha[magenta] = 0
    arr[:, :, 3] = alpha
    return Image.fromarray(arr, "RGBA")


def harden_alpha(im: Image.Image, thr: int = 100) -> Image.Image:
    arr = np.array(im)
    arr[:, :, 3] = np.where(arr[:, :, 3] >= thr, 255, 0).astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


def content_bbox(im: Image.Image, pad: int = 0) -> tuple[int, int, int, int]:
    a = np.array(im)[:, :, 3]
    ys, xs = np.where(a > 0)
    return int(xs.min()) - pad, int(ys.min()) - pad, int(xs.max()) + pad, int(ys.max()) + pad


def extract_palette(im: Image.Image, n: int = PALETTE_N) -> list[tuple[int, int, int]]:
    arr = np.array(im)
    mask = arr[:, :, 3] > 0
    pixels = arr[:, :, :3][mask]
    if len(pixels) == 0:
        return [(0, 0, 0)]
    # Sample + quantize via PIL
    tmp = Image.new("RGBA", im.size)
    tmp.paste(im, (0, 0), im)
    q = tmp.convert("RGB").quantize(colors=n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = q.getpalette()[: n * 3]
    colors = []
    for i in range(0, len(pal), 3):
        colors.append((pal[i], pal[i + 1], pal[i + 2]))
    # Drop near-magenta leftovers from palette
    cleaned = []
    for c in colors:
        if c[0] > 180 and c[2] > 180 and c[1] < 150:
            continue
        cleaned.append(c)
    return cleaned or colors


def remap_to_palette(im: Image.Image, palette: list[tuple[int, int, int]]) -> Image.Image:
    arr = np.array(im)
    out = arr.copy()
    mask = arr[:, :, 3] > 0
    if not mask.any():
        return im
    pal = np.array(palette, dtype=np.int16)
    pixels = arr[:, :, :3][mask].astype(np.int16)
    # Chunked nearest color
    idxs = []
    step = 5000
    for i in range(0, len(pixels), step):
        chunk = pixels[i : i + step]
        # distances to palette
        d = ((chunk[:, None, :] - pal[None, :, :]) ** 2).sum(axis=2)
        idxs.append(d.argmin(axis=1))
    nearest = np.concatenate(idxs)
    mapped = pal[nearest].astype(np.uint8)
    out_rgb = out[:, :, :3]
    out_rgb[mask] = mapped
    out[:, :, :3] = out_rgb
    out[:, :, 3] = np.where(mask, 255, 0).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def remove_tiny_specks(im: Image.Image, min_neighbors: int = 1) -> Image.Image:
    """Remove isolated opaque pixels (noise)."""
    arr = np.array(im)
    a = arr[:, :, 3] > 0
    # count opaque neighbors (4-connected)
    n = np.zeros_like(a, dtype=np.uint8)
    n[1:, :] += a[:-1, :]
    n[:-1, :] += a[1:, :]
    n[:, 1:] += a[:, :-1]
    n[:, :-1] += a[:, 1:]
    kill = a & (n < min_neighbors)
    arr[kill, 3] = 0
    return Image.fromarray(arr, "RGBA")


def to_frame(im: Image.Image, shared_scale: float, bias_left: int = 0) -> Image.Image:
    x0, y0, x1, y1 = content_bbox(im)
    x0 = max(0, x0)
    y0 = max(0, y0)
    x1 = min(im.width - 1, x1)
    y1 = min(im.height - 1, y1)
    crop = im.crop((x0, y0, x1 + 1, y1 + 1))
    new_w = max(1, int(round(crop.width * shared_scale)))
    new_h = max(1, int(round(crop.height * shared_scale)))
    if new_w > 62:
        s = 62 / crop.width
        new_w = 62
        new_h = max(1, int(round(crop.height * s)))
    if new_h > 60:
        s = 60 / crop.height
        new_h = 60
        new_w = max(1, int(round(crop.width * s)))
    scaled = crop.resize((new_w, new_h), Image.NEAREST)
    scaled = harden_alpha(scaled, 128)

    frame = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    paste_x = (FRAME - new_w) // 2 - bias_left
    paste_x = max(1, min(paste_x, FRAME - new_w - 1))
    paste_y = FOOT_Y - new_h + 1
    paste_y = max(0, min(paste_y, FRAME - new_h))
    frame.paste(scaled, (paste_x, paste_y), scaled)
    return harden_alpha(frame, 128)


def measure(im: Image.Image) -> dict:
    a = np.array(im)[:, :, 3]
    ys, xs = np.where(a > 0)
    return {
        "h": int(ys.max() - ys.min() + 1),
        "w": int(xs.max() - xs.min() + 1),
        "y0": int(ys.min()),
        "y1": int(ys.max()),
        "opaque": int(a.sum() // 255),
    }


def build_preview(frames: list[Image.Image], labels: list[str], scale: int = 5) -> Image.Image:
    gap = 10
    cell = FRAME * scale
    w = 24 + len(frames) * cell + (len(frames) - 1) * gap + 24
    h = cell + 56
    prev = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = prev.load()
    for y in range(h):
        for x in range(w):
            c = 200 if ((x // 10) + (y // 10)) % 2 == 0 else 170
            px[x, y] = (c, c, c, 255)
    draw = ImageDraw.Draw(prev)
    for i, fr in enumerate(frames):
        big = fr.resize((cell, cell), Image.NEAREST)
        x = 24 + i * (cell + gap)
        y = 32
        prev.paste(big, (x, y), big)
        draw.text((x + 2, 8), labels[i], fill=(15, 15, 15, 255))
        by = y + FOOT_Y * scale
        draw.line((x, by, x + cell - 1, by), fill=(210, 50, 50, 200), width=1)
    return prev


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)

    cleaned: list[Image.Image] = []
    for src_name, _out_name, _label in POSE_SRCS:
        path = SRC_DIR / src_name
        if not path.exists():
            # fallback flat artifacts path
            path = ART / src_name
        im = Image.open(path)
        im = chroma_key(im)
        im = harden_alpha(im, 90)
        im = remove_tiny_specks(im, min_neighbors=1)
        cleaned.append(im)

    # Shared palette from master ready
    palette = extract_palette(cleaned[0], PALETTE_N)
    print("palette_colors", len(palette))

    remapped = [remap_to_palette(im, palette) for im in cleaned]

    # Shared scale from ready pose height
    x0, y0, x1, y1 = content_bbox(remapped[0])
    idle_h = y1 - y0 + 1
    shared_scale = TARGET_H / idle_h
    print("idle_src_h", idle_h, "shared_scale", round(shared_scale, 4))

    frames: list[Image.Image] = []
    labels: list[str] = []
    for i, ((_src, out_name, label), im) in enumerate(zip(POSE_SRCS, remapped)):
        bias = 0 if i < 3 else 2
        # Impact needs room on the right for extended sword — bias body left
        if i == 4:
            bias = 4
        fr = to_frame(im, shared_scale, bias_left=bias)
        # Final palette snap after scale
        fr = remap_to_palette(fr, palette)
        fr = harden_alpha(fr, 128)
        frames.append(fr)
        labels.append(label)
        dest = OUT / out_name
        fr.save(dest)
        fr.save(ART / out_name)
        m = measure(fr)
        print(f"{out_name}: {m} corner={fr.getpixel((0,0))}")

    preview = build_preview(frames, labels, scale=5)
    preview.save(OUT / "pirate_phase1_poses_preview_x5.png")
    preview.save(ART / "pirate_phase1_poses_preview_x5.png")

    strip = Image.new("RGBA", (FRAME * 6 + 20, FRAME), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        strip.paste(fr, (i * (FRAME + 4), 0), fr)
    strip4 = strip.resize((strip.width * 4, strip.height * 4), Image.NEAREST)
    strip4.save(OUT / "pirate_phase1_poses_strip_x4.png")
    strip4.save(ART / "pirate_phase1_poses_strip_x4.png")

    # Save palette reference
    sw = Image.new("RGBA", (len(palette) * 8, 16), (0, 0, 0, 0))
    for i, c in enumerate(palette):
        for y in range(16):
            for x in range(8):
                sw.putpixel((i * 8 + x, y), (*c, 255))
    sw.save(OUT / "pirate_phase1_palette.png")

    foots = [measure(f)["y1"] for f in frames]
    heights = [measure(f)["h"] for f in frames]
    print("heights", heights)
    print("foot_y", foots)
    assert all(f.getpixel((0, 0))[3] == 0 for f in frames), "transparency failed"
    assert max(foots) - min(foots) <= 1, f"baseline jitter {foots}"
    # Standing poses must be tall; crouch/lunge may be shorter by design.
    assert heights[0] >= 50, f"idle too short {heights[0]}"
    assert heights[1] >= 48, f"anticipation too short {heights[1]}"
    assert all(h >= 32 for h in heights), f"pose collapsed {heights}"
    print("QA PASS (crouch frames may be shorter vertically — expected)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
