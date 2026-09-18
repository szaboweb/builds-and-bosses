"""Core constants and configuration for Crucible of Builds."""

import os
from enum import Enum, auto

# Screen / Window settings
SCREEN_WIDTH = 1280
SCREEN_HEIGHT = 720
FPS = 60
TITLE = "Crucible of Builds — D&D Multiclass Action RPG"

# Colors (Tailored modern dark fantasy palette)
COLOR_BG_DARK = (15, 17, 26)         # Deep slate/black
COLOR_BG_PANEL = (25, 28, 42)        # Dark stone panel
COLOR_PANEL_BORDER = (55, 62, 88)    # Muted border
COLOR_TEXT_LIGHT = (235, 240, 245)   # Crisp off-white
COLOR_TEXT_MUTED = (140, 148, 170)   # Grey-blue
COLOR_ACCENT_GOLD = (230, 175, 45)   # D&D Gold
COLOR_ACCENT_RED = (210, 55, 60)     # Health / Danger / Boss
COLOR_ACCENT_BLUE = (60, 140, 240)   # Mana / Arcane
COLOR_ACCENT_GREEN = (50, 190, 110)  # Stamina / Buffs
COLOR_ACCENT_PURPLE = (155, 75, 225) # Epic / Curse / Void
COLOR_ACCENT_ORANGE = (245, 130, 32) # Legendary

# Paths
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ASSETS_DIR = os.path.join(BASE_DIR, "assets")
DATA_DIR = os.path.join(BASE_DIR, "data")


class GameStateId(Enum):
    """Identifies the active top-level game state."""
    MAIN_MENU = auto()
    CHARACTER_BUILDER = auto()
    DUNGEON_RUN = auto()
    SCOREBOARD = auto()
    BOSS_EDITOR = auto()
    SETTINGS = auto()


class Rarity(Enum):
    COMMON = "Common"
    RARE = "Rare"
    EPIC = "Epic"
    LEGENDARY = "Legendary"
