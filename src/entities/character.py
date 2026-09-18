"""
Character model — handles multiclass composition and stat derivation.

A Character is defined by:
  - A name
  - A dict of {class_id: levels} representing the multiclass split
  - Base attribute scores (manually assigned at build time)
  - Equipped items
  - Active debuffs / curses
  - A set of equipped active abilities (the skillbar)
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Dict, List, Optional, TYPE_CHECKING

from src.entities.attributes import Attributes, DerivedStats, modifier, Attribute
from src.entities.classes import ClassDefinition, Ability, ArmorType, CLASSES

if TYPE_CHECKING:
    from src.combat.debuffs import Debuff


@dataclass
class ClassLevel:
    """A single class contribution in a multiclass character."""
    class_id: str
    levels: int   # 1 .. 10

    @property
    def definition(self) -> ClassDefinition:
        return CLASSES[self.class_id]


class Character:
    """
    Complete character model.
    
    Usage:
        char = Character("Zalazar")
        char.add_class("paladin", 4)
        char.add_class("wizard", 2)
        char.attributes.STR = 14
        char.build()          # derives all stats
    """

    PROFICIENCY_BY_TOTAL_LEVEL = [2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 6, 6]

    def __init__(self, name: str):
        self.name = name
        self.class_levels: Dict[str, int] = {}   # class_id -> level count
        self.attributes = Attributes()
        self.stats = DerivedStats()

        # Runtime position (world units)
        self.x: float = 0.0
        self.y: float = 0.0

        # Active debuffs applied during the dungeon run
        self.debuffs: List["Debuff"] = []

        # Skillbar — up to 6 active ability slots
        self.skillbar: List[Optional[Ability]] = [None] * 6

        # Built flag — stats are valid only after build()
        self._built: bool = False

    # ------------------------------------------------------------------
    # Build composition
    # ------------------------------------------------------------------

    def add_class(self, class_id: str, levels: int) -> None:
        """Add or update a class contribution. Raises ValueError if class unknown."""
        if class_id not in CLASSES:
            raise ValueError(f"Unknown class: '{class_id}'")
        if levels < 1:
            raise ValueError("Levels must be >= 1")
        self.class_levels[class_id] = levels
        self._built = False

    def remove_class(self, class_id: str) -> None:
        self.class_levels.pop(class_id, None)
        self._built = False

    @property
    def total_level(self) -> int:
        return sum(self.class_levels.values())

    @property
    def proficiency_bonus(self) -> int:
        idx = min(self.total_level - 1, len(self.PROFICIENCY_BY_TOTAL_LEVEL) - 1)
        return self.PROFICIENCY_BY_TOTAL_LEVEL[max(idx, 0)]

    # ------------------------------------------------------------------
    # Stat derivation
    # ------------------------------------------------------------------

    def build(self) -> None:
        """Derive all stats from attributes and class levels. Call after any change."""
        attrs = self.attributes

        # Proficiency
        pb = self.proficiency_bonus

        # Max HP: sum of each class's hp_per_level * its level + CON mod * total level
        base_hp = sum(
            CLASSES[cid].hp_per_level() * lvl
            for cid, lvl in self.class_levels.items()
        )
        con_bonus = modifier(attrs.CON) * self.total_level
        max_hp = max(int(base_hp) + con_bonus, 1)

        # Max Mana: sum of mana_per_level * level + INT mod * arcane levels
        arcane_levels = sum(
            lvl for cid, lvl in self.class_levels.items()
            if CLASSES[cid].mana_die > 0
        )
        base_mana = sum(
            CLASSES[cid].mana_per_level() * lvl
            for cid, lvl in self.class_levels.items()
        )
        int_bonus = modifier(attrs.INT) * arcane_levels
        max_mana = max(int(base_mana) + int_bonus, 0)

        # Armor Class: 10 + DEX mod, upgraded by best armor proficiency
        best_armor = max(
            (CLASSES[cid].armor_proficiency for cid in self.class_levels),
            default=ArmorType.NONE
        )
        dex_mod = modifier(attrs.DEX)
        if best_armor == ArmorType.HEAVY:
            # Heavy armour: fixed base AC 16, no DEX
            ac = 16
        elif best_armor == ArmorType.MEDIUM:
            # Medium: 13 + DEX (max +2)
            ac = 13 + min(dex_mod, 2)
        elif best_armor == ArmorType.LIGHT:
            # Light: 11 + full DEX
            ac = 11 + dex_mod
        else:
            # Unarmoured: 10 + full DEX
            ac = 10 + dex_mod

        # Attack bonuses
        str_mod = modifier(attrs.STR)
        wis_mod = modifier(attrs.WIS)
        cha_mod = modifier(attrs.CHA)
        int_mod = modifier(attrs.INT)

        best_spell_mod = max(int_mod, wis_mod, cha_mod)

        # Movement speed — heavy armour slightly penalised without STR threshold
        move_speed = 180.0
        if best_armor == ArmorType.HEAVY and attrs.STR < 15:
            move_speed -= 30.0

        self.stats = DerivedStats(
            max_hp=max_hp,
            max_mana=max_mana,
            armor_class=ac,
            initiative=dex_mod,
            melee_attack_bonus=max(str_mod, dex_mod) + pb,
            spell_attack_bonus=best_spell_mod + pb,
            melee_damage_bonus=str_mod,
            move_speed=move_speed,
            proficiency_bonus=pb
        )
        # Restore to max on fresh build
        self.stats.current_hp = max_hp
        self.stats.current_mana = max_mana

        # Auto-populate skillbar with first available class abilities
        self._auto_populate_skillbar()
        self._built = True

    def _auto_populate_skillbar(self) -> None:
        """Fill skillbar with unlocked abilities (active only, no passives)."""
        slot = 0
        self.skillbar = [None] * 6
        for cid, lvl in self.class_levels.items():
            cls_def = CLASSES[cid]
            for level_idx, ability in enumerate(cls_def.abilities_by_level):
                if ability is None:
                    continue
                if level_idx >= lvl:
                    break
                if ability.is_passive:
                    continue  # Passives always active; not placed in bar
                if slot < 6:
                    self.skillbar[slot] = ability
                    slot += 1

    # ------------------------------------------------------------------
    # Passive ability checks (used by dungeon encounter logic)
    # ------------------------------------------------------------------

    def has_passive(self, ability_id: str) -> bool:
        """Return True if the character has the named passive ability unlocked."""
        for cid, lvl in self.class_levels.items():
            cls_def = CLASSES[cid]
            for level_idx, ability in enumerate(cls_def.abilities_by_level):
                if ability is None:
                    continue
                if level_idx >= lvl:
                    break
                if ability.id == ability_id and ability.is_passive:
                    return True
        return False

    def can_disarm_trap(self) -> bool:
        return self.has_passive("disarm_trap")

    def can_dispel_curse(self) -> bool:
        """True if Paladin/Cleric levels grant the dispel_curse active ability."""
        return any(
            ab is not None and ab.id == "dispel_curse"
            for ab in self.skillbar
        )

    def has_aoe(self) -> bool:
        """True if the character has an AoE spell (Fireball, etc.) in their bar."""
        aoe_ids = {"fireball"}
        return any(
            ab is not None and ab.id in aoe_ids
            for ab in self.skillbar
        )

    # ------------------------------------------------------------------
    # Dungeon-state helpers
    # ------------------------------------------------------------------

    @property
    def is_alive(self) -> bool:
        return self.stats.current_hp > 0

    def take_damage(self, amount: int) -> int:
        """Apply damage. Returns actual HP lost."""
        actual = min(self.stats.current_hp, amount)
        self.stats.current_hp -= actual
        return actual

    def heal(self, amount: int) -> int:
        """Restore HP up to max. Returns actual HP restored."""
        space = self.stats.max_hp - self.stats.current_hp
        actual = min(space, amount)
        self.stats.current_hp += actual
        return actual

    def spend_mana(self, amount: int) -> bool:
        """Attempt to spend mana. Returns True if successful."""
        if self.stats.current_mana >= amount:
            self.stats.current_mana -= amount
            return True
        return False

    def reduce_max_hp(self, amount: int) -> None:
        """Permanently reduce max HP for this run (Wounded curse)."""
        self.stats.max_hp = max(self.stats.max_hp - amount, 1)
        self.stats.current_hp = min(self.stats.current_hp, self.stats.max_hp)

    def drain_mana(self, amount: int) -> None:
        """Drain mana (RuneGate curse)."""
        self.stats.current_mana = max(self.stats.current_mana - amount, 0)

    def __repr__(self) -> str:
        classes = " / ".join(
            f"{CLASSES[cid].name} {lvl}"
            for cid, lvl in self.class_levels.items()
        )
        return f"<Character '{self.name}' [{classes}] Lvl {self.total_level}>"
