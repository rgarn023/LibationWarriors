#!/usr/bin/env python3
"""Write Godot 4 pixel-art .import stubs for PNG sprite sheets.

Usage:
  python3 tools/write_pixel_import.py assets/sprites/attacks

Import dock equivalents:
  compress/mode = 0          (Lossless)
  mipmaps/generate = false
Project still needs textures/canvas_textures/default_texture_filter=0 (Nearest).
"""

from __future__ import annotations

import hashlib
import sys
from pathlib import Path


IMPORT_TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://{uid}"
path="res://.godot/imported/{stem}-{digest}.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="res://{rel}"
dest_files=["res://.godot/imported/{stem}-{digest}.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""


def _uid(path: Path) -> str:
    h = hashlib.md5(str(path).encode()).hexdigest()[:16]
    return f"px{h}"


def _digest(path: Path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest()[:32]


def write_import(png: Path, root: Path) -> Path:
    rel = png.relative_to(root).as_posix()
    out = png.with_suffix(png.suffix + ".import")
    text = IMPORT_TEMPLATE.format(
        uid=_uid(png),
        stem=png.name,
        digest=_digest(png),
        rel=rel,
    )
    out.write_text(text)
    return out


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    targets = sys.argv[1:] or ["assets/sprites/attacks"]
    written = 0
    for t in targets:
        p = (root / t).resolve() if not Path(t).is_absolute() else Path(t)
        files = [p] if p.is_file() else sorted(p.glob("*.png"))
        for png in files:
            if not png.is_file():
                continue
            out = write_import(png, root)
            print("wrote", out.relative_to(root))
            written += 1
    if written == 0:
        print("No PNGs found. Drop sheets into assets/sprites/attacks/ first.")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
