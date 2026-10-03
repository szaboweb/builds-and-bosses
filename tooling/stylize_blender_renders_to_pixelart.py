"""Convert transparent-background Blender renders of the Fighter_Rig into
64x64 2D pixel-art game sprites.

The Blender 3D rig (`fighter.blend`, `Fighter_Rig` armature) exists only to
get deterministic, perfectly consistent joint angles/proportions for each
movement type (zero drift between frames, unlike per-frame AI regeneration).
The actual game asset must still be 2D pixel art, so this script takes the
clean, already-correct 3D renders and converts them to pixel art via
supersampled downscale + palette quantization - a fully deterministic
image-processing step, no AI involved.

Usage:
    python tooling/stylize_blender_renders_to_pixelart.py <input_dir> [--output-dir DIR] [--size 64] [--colors 24]
"""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter

DEFAULT_SIZE = 64
DEFAULT_COLORS = 24
OUTLINE_COLOR = (12, 10, 9)


def add_outline(image: Image.Image) -> Image.Image:
    # 1px dilation of the alpha mask: the ring it adds is exactly where the
    # outline goes, so the silhouette reads clearly even at 64x64.
    alpha = image.getchannel("A")
    dilated = alpha.filter(ImageFilter.MaxFilter(3))
    ring = ImageChops.subtract(dilated, alpha)
    outline_layer = Image.new("RGBA", image.size, (*OUTLINE_COLOR, 255))
    result = Image.composite(outline_layer, image, ring)
    result.putalpha(dilated)
    return result


def stylize(source_path: Path, size: int, colors: int) -> Image.Image:
    source = Image.open(source_path).convert("RGBA")
    # Render resolution is deliberately higher than the target sprite size
    # (anti-aliased 3D render); a box filter supersamples it down cleanly,
    # same technique already used for the game's other sprite sheets.
    downscaled = source.resize((size, size), Image.Resampling.BOX)

    alpha = downscaled.getchannel("A")
    rgb = downscaled.convert("RGB")
    # Quantize to a small palette for a retro look; quantizing drags fully
    # transparent pixels' RGB into the palette too, so the alpha mask is
    # captured first and reapplied verbatim afterward - palette locking must
    # never change the silhouette.
    quantized = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    result = quantized.convert("RGBA")
    result.putalpha(alpha)
    return add_outline(result)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input_dir", type=Path)
    parser.add_argument("--output-dir", type=Path, default=None)
    parser.add_argument("--size", type=int, default=DEFAULT_SIZE)
    parser.add_argument("--colors", type=int, default=DEFAULT_COLORS)
    args = parser.parse_args()

    output_dir = args.output_dir or (args.input_dir / "pixelart")
    output_dir.mkdir(parents=True, exist_ok=True)

    source_paths = sorted(args.input_dir.glob("*.png"))
    for source_path in source_paths:
        sprite = stylize(source_path, args.size, args.colors)
        sprite.save(output_dir / source_path.name)
    print(f"Wrote {len(source_paths)} pixel-art sprite(s) to {output_dir}")


if __name__ == "__main__":
    main()
