"""Entry point for Crucible of Builds."""

import sys
import argparse
import os

# Ensure project root is in sys.path
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from src.core.engine import GameEngine


def parse_args():
    parser = argparse.ArgumentParser(description="Crucible of Builds — D&D Action RPG")
    parser.add_argument(
        "--headless",
        action="store_true",
        help="Run without displaying a window (for testing and CI)"
    )
    parser.add_argument(
        "--test",
        action="store_true",
        help="Run 30 frames in headless mode for verification and exit"
    )
    parser.add_argument(
        "--frames",
        type=int,
        default=None,
        help="Maximum frames to run before terminating"
    )
    return parser.parse_args()


def main():
    args = parse_args()
    
    headless = args.headless or args.test
    max_frames = 30 if args.test else args.frames

    print(f"Indítás: Crucible of Builds (Headless={headless}, MaxFrames={max_frames})")
    engine = GameEngine(headless=headless, max_frames=max_frames)
    engine.initialize()
    engine.run()
    print("A motor sikeresen leállt.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
