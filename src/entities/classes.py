"""
Class definitions for the multiclass system.

Each D&D-inspired class provides:
  - Hit Die (for max HP calculation)
  - Mana die (arcane classes) or stamina die (martial classes) per level
  - Proficiencies granted at level 1 of the class
  - Armor proficiency level (none / light / medium / heavy)
  - Per-level ability unlocks
"""

from enum import Enum, auto
from dataclasses import dataclass, field
from typing import List, Optional, Callable

from src.entities.attributes import Attributes, DerivedStats, modifier


class ArmorType(Enum):
    NONE = 0
    LIGHT = 1
    MEDIUM = 2
    HEAVY = 3


@dataclass
class Ability:
    """An active or passive character ability/spell."""
    id: str
    name: str
    description: str
    cooldown: float          # seconds; 0 = passive
    mana_cost: int = 0
    stamina_cost: int = 0
    is_passive: bool = False
    icon_key: str = ""        # key into the sprite atlas


@dataclass
class ClassDefinition:
    """Static configuration for one D&D class."""
    id: str
    name: str
    hit_die: int              # d6/d8/d10/d12 — average used for HP per level
    mana_die: int             # 0 for pure martials
    armor_proficiency: ArmorType
    # Abilities granted at each level 1..10 (index 0 = level 1)
    abilities_by_level: List[Optional[Ability]] = field(default_factory=list)

    def hp_per_level(self) -> float:
        """Average HP gained per level (used for deterministic stat calc)."""
        return (self.hit_die / 2.0) + 1

    def mana_per_level(self) -> float:
        return (self.mana_die / 2.0) + 1 if self.mana_die else 0


# ---------------------------------------------------------------------------
# Ability pool (will grow as we add content)
# ---------------------------------------------------------------------------

ABILITIES: dict[str, Ability] = {
    "power_attack": Ability(
        id="power_attack",
        name="Power Attack",
        description="Trade -2 attack for +1d8 damage.",
        cooldown=0.0,
        stamina_cost=8,
        icon_key="power_attack"
    ),
    "second_wind": Ability(
        id="second_wind",
        name="Second Wind",
        description="Recover 1d10 + level HP as a bonus action.",
        cooldown=30.0,
        icon_key="second_wind"
    ),
    "action_surge": Ability(
        id="action_surge",
        name="Action Surge",
        description="Take an extra full action this round.",
        cooldown=60.0,
        icon_key="action_surge"
    ),
    "sneak_attack": Ability(
        id="sneak_attack",
        name="Sneak Attack",
        description="Deal +Nd6 bonus damage when attacking with advantage.",
        cooldown=0.0,
        is_passive=True,
        icon_key="sneak_attack"
    ),
    "cunning_action": Ability(
        id="cunning_action",
        name="Cunning Action",
        description="Dash, Disengage, or Hide as a bonus action.",
        cooldown=4.0,
        icon_key="cunning_action"
    ),
    "disarm_trap": Ability(
        id="disarm_trap",
        name="Disarm Trap",
        description="Detect and disarm traps without triggering them.",
        cooldown=0.0,
        is_passive=True,
        icon_key="disarm_trap"
    ),
    "fireball": Ability(
        id="fireball",
        name="Fireball",
        description="8d6 fire damage in 5m radius.",
        cooldown=6.0,
        mana_cost=30,
        icon_key="fireball"
    ),
    "misty_step": Ability(
        id="misty_step",
        name="Misty Step",
        description="Teleport up to 9m to a visible location.",
        cooldown=12.0,
        mana_cost=15,
        icon_key="misty_step"
    ),
    "arcane_recovery": Ability(
        id="arcane_recovery",
        name="Arcane Recovery",
        description="Recover mana equal to half your Wizard level (min 1).",
        cooldown=90.0,
        icon_key="arcane_recovery"
    ),
    "lay_on_hands": Ability(
        id="lay_on_hands",
        name="Lay on Hands",
        description="Restore up to 5×Paladin level HP total.",
        cooldown=0.0,
        icon_key="lay_on_hands"
    ),
    "divine_smite": Ability(
        id="divine_smite",
        name="Divine Smite",
        description="On hit, expend mana to deal +2d8 radiant damage per level.",
        cooldown=0.0,
        mana_cost=15,
        icon_key="divine_smite"
    ),
    "dispel_curse": Ability(
        id="dispel_curse",
        name="Dispel Magic / Remove Curse",
        description="Remove one active Curse debuff from self.",
        cooldown=25.0,
        mana_cost=20,
        icon_key="dispel_curse"
    ),
    "channel_divinity": Ability(
        id="channel_divinity",
        name="Channel Divinity",
        description="Unleash radiant energy: Turn Undead or Preserve Life.",
        cooldown=45.0,
        mana_cost=0,
        icon_key="channel_divinity"
    ),
    "hunter_mark": Ability(
        id="hunter_mark",
        name="Hunter's Mark",
        description="Mark a target — deal +1d6 damage against it.",
        cooldown=0.0,
        mana_cost=10,
        icon_key="hunter_mark"
    ),
    "colossus_slayer": Ability(
        id="colossus_slayer",
        name="Colossus Slayer",
        description="Deal +1d8 bonus damage to an injured enemy once per turn.",
        cooldown=0.0,
        is_passive=True,
        icon_key="colossus_slayer"
    ),
    "wild_magic_surge": Ability(
        id="wild_magic_surge",
        name="Wild Magic Surge",
        description="Random chaotic effect after each spell cast.",
        cooldown=0.0,
        is_passive=True,
        icon_key="wild_magic_surge"
    ),
    "tides_of_chaos": Ability(
        id="tides_of_chaos",
        name="Tides of Chaos",
        description="Gain advantage on one roll; risk Wild Magic Surge.",
        cooldown=20.0,
        icon_key="tides_of_chaos"
    ),
}


# ---------------------------------------------------------------------------
# Class definitions
# ---------------------------------------------------------------------------

CLASSES: dict[str, ClassDefinition] = {
    "fighter": ClassDefinition(
        id="fighter",
        name="Fighter",
        hit_die=10,
        mana_die=0,
        armor_proficiency=ArmorType.HEAVY,
        abilities_by_level=[
            ABILITIES["power_attack"],    # L1
            ABILITIES["second_wind"],     # L2
            ABILITIES["action_surge"],    # L3
            None, None, None, None, None, None, None
        ]
    ),
    "rogue": ClassDefinition(
        id="rogue",
        name="Rogue",
        hit_die=8,
        mana_die=0,
        armor_proficiency=ArmorType.LIGHT,
        abilities_by_level=[
            ABILITIES["sneak_attack"],    # L1 (passive)
            ABILITIES["disarm_trap"],     # L2 (passive)
            ABILITIES["cunning_action"],  # L3
            None, None, None, None, None, None, None
        ]
    ),
    "wizard": ClassDefinition(
        id="wizard",
        name="Wizard",
        hit_die=6,
        mana_die=8,
        armor_proficiency=ArmorType.NONE,
        abilities_by_level=[
            ABILITIES["fireball"],        # L1 (acquired early for gameplay)
            ABILITIES["misty_step"],      # L2
            ABILITIES["arcane_recovery"], # L3
            None, None, None, None, None, None, None
        ]
    ),
    "paladin": ClassDefinition(
        id="paladin",
        name="Paladin",
        hit_die=10,
        mana_die=6,
        armor_proficiency=ArmorType.HEAVY,
        abilities_by_level=[
            ABILITIES["lay_on_hands"],   # L1
            ABILITIES["divine_smite"],   # L2
            ABILITIES["dispel_curse"],   # L3
            None, None, None, None, None, None, None
        ]
    ),
    "cleric": ClassDefinition(
        id="cleric",
        name="Cleric",
        hit_die=8,
        mana_die=8,
        armor_proficiency=ArmorType.MEDIUM,
        abilities_by_level=[
            ABILITIES["channel_divinity"], # L1
            ABILITIES["dispel_curse"],     # L2
            None, None, None, None, None, None, None, None
        ]
    ),
    "ranger": ClassDefinition(
        id="ranger",
        name="Ranger",
        hit_die=10,
        mana_die=4,
        armor_proficiency=ArmorType.MEDIUM,
        abilities_by_level=[
            ABILITIES["hunter_mark"],     # L1
            ABILITIES["disarm_trap"],     # L2 (passive — wilderness expertise)
            ABILITIES["colossus_slayer"], # L3 (passive)
            None, None, None, None, None, None, None
        ]
    ),
    "sorcerer": ClassDefinition(
        id="sorcerer",
        name="Sorcerer",
        hit_die=6,
        mana_die=10,
        armor_proficiency=ArmorType.NONE,
        abilities_by_level=[
            ABILITIES["fireball"],           # L1
            ABILITIES["tides_of_chaos"],     # L2
            ABILITIES["wild_magic_surge"],   # L3 (passive)
            None, None, None, None, None, None, None
        ]
    ),
}
