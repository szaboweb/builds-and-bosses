"""
HeroSaveManager — save and load hero builds to/from JSON.

Save location: data/heroes/saves/<hero_name>.json
Schema: hero_save/v1

Usage
-----
    from src.core.hero_save_manager import HeroSaveManager
    from src.entities.character import Character

    # Save
    HeroSaveManager.save(character)

    # Load
    char = HeroSaveManager.load("Zalazar")

    # List all saves
    names = HeroSaveManager.list_saves()
"""

import json
import os
import re
from typing import Optional

from src.core.data_loader import DataLoader
from src.entities.character import Character

_PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_SAVES_DIR = os.path.join(_PROJECT_ROOT, "data", "heroes", "saves")

_SCHEMA = "hero_save/v1"
_MAX_SAVES = 20


def _safe_filename(name: str) -> str:
    """Convert hero name to a safe filename (alphanumeric + underscore)."""
    safe = re.sub(r"[^\w\-]", "_", name.strip())
    return safe[:40] or "hero"


class HeroSaveManager:

    @staticmethod
    def save(character: Character) -> str:
        """
        Persist a Character to data/heroes/saves/<name>.json.

        Returns the full path of the saved file.
        Raises ValueError if the character has not been built yet.
        """
        if not character._built:
            raise ValueError("Call character.build() before saving.")

        os.makedirs(_SAVES_DIR, exist_ok=True)

        payload = {
            "_schema": _SCHEMA,
            "name": character.name,
            "class_levels": dict(character.class_levels),
            "attributes": {
                "STR": character.attributes.STR,
                "DEX": character.attributes.DEX,
                "CON": character.attributes.CON,
                "INT": character.attributes.INT,
                "WIS": character.attributes.WIS,
                "CHA": character.attributes.CHA,
            },
        }

        filename = _safe_filename(character.name) + ".json"
        path = os.path.join(_SAVES_DIR, filename)

        with open(path, "w", encoding="utf-8") as f:
            json.dump(payload, f, indent=2, ensure_ascii=False)

        # Invalidate DataLoader cache for this file so reload picks up changes
        DataLoader.clear_cache()
        return path

    @staticmethod
    def load(name: str) -> Character:
        """
        Load a saved hero by name (case-sensitive, matches filename).

        Raises FileNotFoundError if the save does not exist.
        Raises ValueError on schema mismatch or unknown class.
        """
        filename = _safe_filename(name) + ".json"
        path = os.path.join(_SAVES_DIR, filename)

        if not os.path.isfile(path):
            raise FileNotFoundError(
                f"[HeroSaveManager] No save found for '{name}' at {path}"
            )

        with open(path, encoding="utf-8") as f:
            data = json.load(f)

        schema = data.get("_schema", "")
        if schema != _SCHEMA:
            raise ValueError(
                f"[HeroSaveManager] Unexpected schema '{schema}' in {filename}"
            )

        return HeroSaveManager.from_dict(data)

    @staticmethod
    def from_dict(data: dict) -> Character:
        """Build a Character from a hero_save/v1 dict (used by load and UI)."""
        char = Character(data["name"])
        for cid, lvl in data["class_levels"].items():
            char.add_class(cid, int(lvl))
        attrs = data.get("attributes", {})
        char.attributes.STR = attrs.get("STR", 10)
        char.attributes.DEX = attrs.get("DEX", 10)
        char.attributes.CON = attrs.get("CON", 10)
        char.attributes.INT = attrs.get("INT", 10)
        char.attributes.WIS = attrs.get("WIS", 10)
        char.attributes.CHA = attrs.get("CHA", 10)
        char.build()
        return char

    @staticmethod
    def list_saves() -> list[str]:
        """
        Return a list of saved hero names (sorted alphabetically).
        Names are derived from filenames — the display name is inside the JSON.
        """
        if not os.path.isdir(_SAVES_DIR):
            return []
        saves = []
        for fname in sorted(os.listdir(_SAVES_DIR)):
            if not fname.endswith(".json") or fname.startswith("_"):
                continue
            path = os.path.join(_SAVES_DIR, fname)
            try:
                with open(path, encoding="utf-8") as f:
                    data = json.load(f)
                saves.append(data.get("name", fname[:-5]))
            except (json.JSONDecodeError, OSError):
                pass  # corrupt save — skip silently
        return saves[:_MAX_SAVES]

    @staticmethod
    def delete(name: str) -> bool:
        """Delete a save by hero name. Returns True if deleted, False if not found."""
        filename = _safe_filename(name) + ".json"
        path = os.path.join(_SAVES_DIR, filename)
        if os.path.isfile(path):
            os.remove(path)
            return True
        return False
