"""
Character attribute and statistics model.

Implements the D&D 5e-inspired six-attribute system (STR, DEX, CON, INT, WIS, CHA)
with derived statistics (max HP, max Mana, AC, initiative, attack/spell modifiers).
"""

from dataclasses import dataclass, field
from enum import Enum
from typing import Dict


class Attribute(Enum):
    STR = "Strength"
    DEX = "Dexterity"
    CON = "Constitution"
    INT = "Intelligence"
    WIS = "Wisdom"
    CHA = "Charisma"


def modifier(score: int) -> int:
    """D&D ability modifier formula: floor((score - 10) / 2)."""
    return (score - 10) // 2


@dataclass
class Attributes:
    """Raw D&D attribute scores (typically 8–20 range)."""
    STR: int = 10
    DEX: int = 10
    CON: int = 10
    INT: int = 10
    WIS: int = 10
    CHA: int = 10

    def get(self, attr: Attribute) -> int:
        return getattr(self, attr.name)

    def mod(self, attr: Attribute) -> int:
        return modifier(self.get(attr))

    def as_dict(self) -> Dict[str, int]:
        return {a.name: self.get(a) for a in Attribute}


@dataclass
class DerivedStats:
    """
    Stats calculated from base Attributes + class bonuses.
    Updated whenever attributes or class levels change.
    """
    max_hp: int = 0
    max_mana: int = 0
    armor_class: int = 10
    initiative: int = 0          # DEX modifier (with possible class bonus)
    melee_attack_bonus: int = 0  # STR/DEX mod + proficiency
    spell_attack_bonus: int = 0  # INT/WIS/CHA mod + proficiency
    melee_damage_bonus: int = 0  # STR mod
    move_speed: float = 180.0    # pixels/second base
    proficiency_bonus: int = 2

    # These are runtime stats; they start equal to max but change during play
    current_hp: int = field(init=False, default=0)
    current_mana: int = field(init=False, default=0)

    def __post_init__(self):
        self.current_hp = self.max_hp
        self.current_mana = self.max_mana

    @property
    def hp_ratio(self) -> float:
        return self.current_hp / max(self.max_hp, 1)

    @property
    def mana_ratio(self) -> float:
        return self.current_mana / max(self.max_mana, 1)
