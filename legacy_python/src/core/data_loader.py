"""
DataLoader — centralised JSON asset loader.

All game data (bosses, heroes, items, dungeons) is loaded through
this module. It validates the _schema field, caches results, and
raises clear errors on missing or malformed files.

Usage
-----
    from src.core.data_loader import DataLoader
    boss_data = DataLoader.boss("boss_001_malakar")
    hero_defaults = DataLoader.hero_defaults()
"""

import json
import os
from typing import Any

# Resolve data/ relative to project root (two levels up from this file)
_PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_DATA_DIR = os.path.join(_PROJECT_ROOT, "data")

_CACHE: dict[str, Any] = {}


def _load(relative_path: str) -> dict:
    """Load and cache a JSON file relative to data/. Raises on error."""
    if relative_path in _CACHE:
        return _CACHE[relative_path]

    full_path = os.path.join(_DATA_DIR, relative_path)
    if not os.path.isfile(full_path):
        raise FileNotFoundError(
            f"[DataLoader] Missing data file: {full_path}\n"
            f"  Expected at: data/{relative_path}"
        )

    with open(full_path, encoding="utf-8") as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError as exc:
            raise ValueError(f"[DataLoader] Invalid JSON in data/{relative_path}: {exc}") from exc

    _CACHE[relative_path] = data
    return data


class DataLoader:
    """Namespace for typed data-loading helpers."""

    # ------------------------------------------------------------------
    # Bosses
    # ------------------------------------------------------------------

    @staticmethod
    def boss(boss_id: str) -> dict:
        """
        Load a boss stat-block by ID.

        Args:
            boss_id: filename without extension, e.g. "boss_001_malakar"

        Returns:
            Parsed boss dict conforming to schema boss/v1.
        """
        data = _load(f"bosses/{boss_id}.json")
        schema = data.get("_schema", "")
        if not schema.startswith("boss/"):
            raise ValueError(
                f"[DataLoader] bosses/{boss_id}.json has unexpected _schema: '{schema}'"
            )
        return data

    @staticmethod
    def all_bosses() -> list[dict]:
        """Load all boss JSON files in data/bosses/ sorted by filename."""
        bosses_dir = os.path.join(_DATA_DIR, "bosses")
        files = sorted(
            f for f in os.listdir(bosses_dir)
            if f.endswith(".json") and not f.startswith("_")
        )
        return [DataLoader.boss(f[:-5]) for f in files]

    # ------------------------------------------------------------------
    # Heroes
    # ------------------------------------------------------------------

    @staticmethod
    def hero_defaults() -> dict:
        """
        Load the default hero attribute block.

        Returns:
            Dict with key "attributes": {STR, DEX, CON, INT, WIS, CHA}
        """
        return _load("heroes/default_hero.json")

    # ------------------------------------------------------------------
    # Cache control (useful in tests)
    # ------------------------------------------------------------------

    @staticmethod
    def clear_cache() -> None:
        """Flush the in-memory cache (call between tests)."""
        _CACHE.clear()
