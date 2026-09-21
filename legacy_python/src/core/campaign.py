"""Campaign scaling and character blueprint domain models.

This module is deliberately independent from pygame so campaign rules can be
validated by headless tests and reused by UI states, saves, and the scoreboard.
"""

from dataclasses import dataclass, field
from enum import Enum
from typing import Dict, FrozenSet, Optional

from src.entities.attributes import Attributes
from src.entities.character import Character
from src.entities.classes import CLASSES


class HeroLevelMode(Enum):
    """The two level choices offered before each campaign boss."""

    LEVEL_DOWN = "level_down"
    LEVEL_UP = "level_up"


class CampaignPhase(Enum):
    BLUEPRINT = "blueprint"
    GAUNTLET = "gauntlet"
    BOSS = "boss"
    COMPLETE = "complete"


@dataclass(frozen=True)
class BossScaling:
    """One row of the campaign level-gap matrix."""

    boss_number: int
    hero_level_down: int
    hero_level_up: int
    boss_level: int

    @property
    def baseline_gap(self) -> int:
        return self.boss_level - self.hero_level_up


CAMPAIGN_SCALING: tuple[BossScaling, ...] = (
    BossScaling(1, 1, 2, 4),
    BossScaling(2, 2, 4, 6),
    BossScaling(3, 4, 6, 8),
    BossScaling(4, 6, 8, 10),
    BossScaling(5, 8, 10, 12),
    BossScaling(6, 10, 12, 14),
    BossScaling(7, 12, 14, 16),
    BossScaling(8, 14, 16, 18),
    BossScaling(9, 16, 18, 20),
    BossScaling(10, 18, 20, 22),
    BossScaling(11, 18, 20, 24),
)


@dataclass
class CharacterBlueprint:
    """Serializable build choices made at the Blueprint Table."""

    name: str = "Hero"
    class_levels: Dict[str, int] = field(default_factory=dict)
    attributes: Attributes = field(default_factory=Attributes)
    feats: set[str] = field(default_factory=set)
    enhancements: Dict[str, int] = field(default_factory=dict)

    MAX_CLASSES = 3
    ATTRIBUTE_NAMES: FrozenSet[str] = frozenset({
        "STR", "DEX", "CON", "INT", "WIS", "CHA"
    })

    @property
    def total_level(self) -> int:
        return sum(self.class_levels.values())

    @property
    def active_classes(self) -> int:
        return len(self.class_levels)

    def validate(self, hero_level: Optional[int] = None) -> None:
        if not self.name.strip():
            raise ValueError("Blueprint name cannot be empty")
        if not 1 <= self.active_classes <= self.MAX_CLASSES:
            raise ValueError(f"A blueprint must use 1-{self.MAX_CLASSES} classes")
        if any(class_id not in CLASSES for class_id in self.class_levels):
            unknown = next(class_id for class_id in self.class_levels if class_id not in CLASSES)
            raise ValueError(f"Unknown class: '{unknown}'")
        if any(level < 1 for level in self.class_levels.values()):
            raise ValueError("Class levels must be >= 1")
        if hero_level is not None and self.total_level != hero_level:
            raise ValueError(
                f"Blueprint total level ({self.total_level}) must equal hero level ({hero_level})"
            )
        for attr_name in self.ATTRIBUTE_NAMES:
            score = getattr(self.attributes, attr_name)
            if score < 1:
                raise ValueError(f"Attribute {attr_name} must be positive")

    def build_character(self, hero_level: Optional[int] = None) -> Character:
        """Validate and materialize this blueprint as the existing Character model."""
        self.validate(hero_level)
        character = Character(self.name.strip())
        for class_id, levels in self.class_levels.items():
            character.add_class(class_id, levels)
        character.attributes = Attributes(**{
            name: getattr(self.attributes, name)
            for name in self.ATTRIBUTE_NAMES
        })
        character.build()
        return character


class CampaignProgression:
    """Campaign state machine for blueprint, gauntlet, and boss progression."""

    def __init__(self, boss_number: int = 1):
        self.boss_number = boss_number
        self.phase = CampaignPhase.BLUEPRINT
        self.hero_level_mode: Optional[HeroLevelMode] = None
        self.blueprint: Optional[CharacterBlueprint] = None

    @property
    def scaling(self) -> BossScaling:
        if not 1 <= self.boss_number <= len(CAMPAIGN_SCALING):
            raise ValueError(f"Boss number must be 1-{len(CAMPAIGN_SCALING)}")
        return CAMPAIGN_SCALING[self.boss_number - 1]

    @property
    def hero_level(self) -> Optional[int]:
        if self.hero_level_mode is None:
            return None
        if self.hero_level_mode is HeroLevelMode.LEVEL_DOWN:
            return self.scaling.hero_level_down
        return self.scaling.hero_level_up

    def select_blueprint(
        self,
        blueprint: CharacterBlueprint,
        level_mode: HeroLevelMode,
    ) -> None:
        selected_level = (
            self.scaling.hero_level_down
            if level_mode is HeroLevelMode.LEVEL_DOWN
            else self.scaling.hero_level_up
        )
        blueprint.validate(selected_level)
        self.blueprint = blueprint
        self.hero_level_mode = level_mode
        self.phase = CampaignPhase.GAUNTLET

    def start_boss(self) -> None:
        if self.phase is not CampaignPhase.GAUNTLET:
            raise ValueError("The three gauntlet rooms must be cleared first")
        self.phase = CampaignPhase.BOSS

    def complete_boss(self) -> None:
        if self.phase is not CampaignPhase.BOSS:
            raise ValueError("The boss fight is not active")
        self.phase = CampaignPhase.COMPLETE

    def advance(self) -> None:
        """Move to the next boss after a completed campaign fight."""
        if self.phase is not CampaignPhase.COMPLETE:
            raise ValueError("Only a completed boss fight can advance the campaign")
        if self.boss_number == len(CAMPAIGN_SCALING):
            return
        self.boss_number += 1
        self.phase = CampaignPhase.BLUEPRINT
        self.hero_level_mode = None
        self.blueprint = None