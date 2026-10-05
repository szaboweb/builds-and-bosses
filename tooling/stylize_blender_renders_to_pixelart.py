"""Convert transparent-background Blender renders of the Fighter_Rig into
64x64 2D pixel-art game sprites.

The Blender 3D rig (`fighter.blend`, `Fighter_Rig` armature) exists only to
get deterministic, perfectly consistent joint angles/proportions for each
movement type (zero drift between frames, unlike per-frame AI regeneration).
The actual game asset must still be 2D pixel art, so this script takes the
clean, already-correct 3D renders and converts them to pixel art via
supersampled downscale + palette quantization - a fully deterministic
image-processing step, no AI involved.

Note: Batch processing is not atomic. If an error occurs during processing of
subsequent files, previously written sprites remain in the output directory.

Usage:
    python tooling/stylize_blender_renders_to_pixelart.py <input_dir> [--output-dir DIR] [--size 64] [--colors 24]
"""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

from PIL import Image, ImageChops, ImageFilter

DEFAULT_SIZE = 64
DEFAULT_COLORS = 24
MIN_COLORS = 2
MAX_COLORS = 256
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
    with Image.open(source_path) as opened:
        source = opened.convert("RGBA")
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
    quantized = rgb.quantize(
        colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE
    )
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

    if not args.input_dir.exists():
        sys.stderr.write(f"Error: Input directory does not exist: {args.input_dir}\n")
        sys.exit(1)
    if not args.input_dir.is_dir():
        sys.stderr.write(f"Error: Input path is not a directory: {args.input_dir}\n")
        sys.exit(1)

    if args.size <= 0:
        sys.stderr.write(f"Error: Target sprite size must be positive, got {args.size}\n")
        sys.exit(1)

    if args.colors < MIN_COLORS or args.colors > MAX_COLORS:
        sys.stderr.write(
            f"Error: Palette color count must be between {MIN_COLORS} and {MAX_COLORS}, got {args.colors}\n"
        )
        sys.exit(1)

    source_paths = sorted(args.input_dir.glob("*.png"))
    if not source_paths:
        sys.stderr.write(f"Error: No .png files found in input directory: {args.input_dir}\n")
        sys.exit(1)

    output_dir = args.output_dir or (args.input_dir / "pixelart")
    try:
        output_dir.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        sys.stderr.write(f"Error: Failed to create output directory {output_dir}: {exc}\n")
        sys.exit(1)

    for source_path in source_paths:
        try:
            sprite = stylize(source_path, args.size, args.colors)
        except Exception as exc:
            sys.stderr.write(f"Error: Failed to stylize image {source_path}: {exc}\n")
            sys.exit(1)

        try:
            sprite.save(output_dir / source_path.name)
        except OSError as exc:
            sys.stderr.write(
                f"Error: Failed to write sprite {output_dir / source_path.name}: {exc}\n"
            )
            sys.exit(1)

    print(f"Wrote {len(source_paths)} pixel-art sprite(s) to {output_dir}")


if __name__ == "__main__":
    main()
