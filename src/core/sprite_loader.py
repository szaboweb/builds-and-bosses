"""
SpriteLoader — loads and caches PNG sprites from assets/.

Falls back gracefully when a sprite file is missing so the game
runs without assets (circle + emoji placeholder rendering).

Sprite naming convention
------------------------
    assets/characters/<class_id>.png       e.g. assets/characters/fighter.png
    assets/bosses/<boss_id>.png            e.g. assets/bosses/boss_001_malakar.png
    assets/ui/<key>.png                    e.g. assets/ui/hp_bar_frame.png

All sprites are scaled to the requested size on first load and cached.
Alpha channel is preserved (PNG with transparency).

Usage
-----
    from src.core.sprite_loader import SpriteLoader
    surf = SpriteLoader.character("fighter", size=64)   # None if missing
    surf = SpriteLoader.boss("boss_001_malakar", size=80)
"""

import os
import pygame
from typing import Optional

_PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_ASSETS_DIR = os.path.join(_PROJECT_ROOT, "assets")

# Cache: (category, key, size) -> Surface | None
_CACHE: dict[tuple, Optional[pygame.Surface]] = {}


def _load(rel_path: str, size: int) -> Optional[pygame.Surface]:
    """Load, scale, and cache a sprite. Returns None if file missing."""
    key = (rel_path, size)
    if key in _CACHE:
        return _CACHE[key]

    full_path = os.path.join(_ASSETS_DIR, rel_path)
    if not os.path.isfile(full_path):
        _CACHE[key] = None
        return None

    try:
        surf = pygame.image.load(full_path).convert_alpha()
        surf = pygame.transform.smoothscale(surf, (size, size))
        _CACHE[key] = surf
        return surf
    except pygame.error:
        _CACHE[key] = None
        return None


class SpriteLoader:

    @staticmethod
    def character(class_id: str, size: int = 64) -> Optional[pygame.Surface]:
        """Load character sprite for a class. Returns None if not found."""
        return _load(f"characters/{class_id}.png", size)

    @staticmethod
    def boss(boss_id: str, size: int = 80) -> Optional[pygame.Surface]:
        """Load boss sprite. Returns None if not found."""
        return _load(f"bosses/{boss_id}.png", size)

    @staticmethod
    def ui(key: str, size: int = 32) -> Optional[pygame.Surface]:
        """Load a UI element sprite."""
        return _load(f"ui/{key}.png", size)

    @staticmethod
    def clear_cache() -> None:
        """Flush sprite cache (useful after hot-reload in dev)."""
        _CACHE.clear()

    @staticmethod
    def sprite_exists(rel_path: str) -> bool:
        """Check if a sprite file exists without loading it."""
        return os.path.isfile(os.path.join(_ASSETS_DIR, rel_path))

    @staticmethod
    def missing_sprites() -> list[str]:
        """
        Return a list of expected sprite paths that are missing.
        Useful for a dev-mode asset checklist.
        """
        expected = []
        # Characters
        for cls in ["fighter", "rogue", "wizard", "paladin", "cleric", "ranger", "barbarian", "bard"]:
            p = f"characters/{cls}.png"
            if not SpriteLoader.sprite_exists(p):
                expected.append(p)
        # Bosses (scan data/bosses/)
        bosses_dir = os.path.join(_PROJECT_ROOT, "data", "bosses")
        if os.path.isdir(bosses_dir):
            for fname in sorted(os.listdir(bosses_dir)):
                if fname.endswith(".json") and not fname.startswith("_"):
                    boss_id = fname[:-5]
                    p = f"bosses/{boss_id}.png"
                    if not SpriteLoader.sprite_exists(p):
                        expected.append(p)
        return expected
