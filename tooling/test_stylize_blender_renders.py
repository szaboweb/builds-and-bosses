"""Unit and CLI tests for stylize_blender_renders_to_pixelart.py."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from PIL import Image

SCRIPT_PATH = Path(__file__).parent / "stylize_blender_renders_to_pixelart.py"


def run_stylizer(*args: str) -> subprocess.CompletedProcess[str]:
    cmd = [sys.executable, str(SCRIPT_PATH), *args]
    return subprocess.run(cmd, capture_output=True, text=True)


class TestStylizeBlenderRendersCLI(unittest.TestCase):
    def test_missing_input_directory_fails(self) -> None:
        result = run_stylizer("nonexistent_directory_xyz")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Input directory does not exist", result.stderr)

    def test_input_is_file_fails(self) -> None:
        with tempfile.NamedTemporaryFile(suffix=".png") as tmp:
            result = run_stylizer(tmp.name)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Input path is not a directory", result.stderr)

    def test_empty_input_directory_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            result = run_stylizer(tmpdir)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("No .png files found", result.stderr)

    def test_non_positive_size_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            img = Image.new("RGBA", (128, 128), (255, 0, 0, 255))
            img.save(Path(tmpdir) / "frame_001.png")

            result_zero = run_stylizer(tmpdir, "--size", "0")
            self.assertNotEqual(result_zero.returncode, 0)
            self.assertIn("Target sprite size must be positive", result_zero.stderr)

            result_neg = run_stylizer(tmpdir, "--size", "-8")
            self.assertNotEqual(result_neg.returncode, 0)
            self.assertIn("Target sprite size must be positive", result_neg.stderr)

    def test_invalid_colors_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            img = Image.new("RGBA", (128, 128), (255, 0, 0, 255))
            img.save(Path(tmpdir) / "frame_001.png")

            result_too_few = run_stylizer(tmpdir, "--colors", "1")
            self.assertNotEqual(result_too_few.returncode, 0)
            self.assertIn("Palette color count must be between", result_too_few.stderr)

            result_too_many = run_stylizer(tmpdir, "--colors", "300")
            self.assertNotEqual(result_too_many.returncode, 0)
            self.assertIn("Palette color count must be between", result_too_many.stderr)

    def test_corrupted_png_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            corrupt_file = Path(tmpdir) / "corrupt.png"
            corrupt_file.write_bytes(b"NOT_A_VALID_PNG_CONTENT")

            result = run_stylizer(tmpdir)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Failed to stylize image", result.stderr)

    def test_output_file_as_directory_conflict_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            img = Image.new("RGBA", (128, 128), (255, 0, 0, 255))
            img.save(Path(tmpdir) / "frame_001.png")

            out_dir = Path(tmpdir) / "conflict_out"
            out_dir.mkdir()
            # Create a directory where the output file should be written to trigger a save error
            (out_dir / "frame_001.png").mkdir()

            result = run_stylizer(tmpdir, "--output-dir", str(out_dir))
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Failed to write sprite", result.stderr)

    def test_successful_conversion(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            in_dir = Path(tmpdir) / "input"
            in_dir.mkdir()
            out_dir = Path(tmpdir) / "output"

            # Create a test render: 128x128 with a centered 64x64 blue rectangle and transparent edges
            img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
            for x in range(32, 96):
                for y in range(32, 96):
                    img.putpixel((x, y), (50, 100, 200, 255))
            img.save(in_dir / "frame_001.png")

            result = run_stylizer(
                str(in_dir),
                "--output-dir",
                str(out_dir),
                "--size",
                "64",
                "--colors",
                "16",
            )
            self.assertEqual(result.returncode, 0)
            self.assertIn("Wrote 1 pixel-art sprite(s)", result.stdout)

            out_file = out_dir / "frame_001.png"
            self.assertTrue(out_file.exists())

            with Image.open(out_file) as output_img:
                self.assertEqual(output_img.size, (64, 64))
                self.assertEqual(output_img.mode, "RGBA")
                # Corner pixel should be transparent
                corner_alpha = output_img.getpixel((0, 0))[3]
                self.assertEqual(corner_alpha, 0)
                # Center pixel should be opaque
                center_alpha = output_img.getpixel((32, 32))[3]
                self.assertEqual(center_alpha, 255)


if __name__ == "__main__":
    unittest.main()
