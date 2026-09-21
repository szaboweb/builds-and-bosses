"""
Combat module — debuff dataclass.

TODO: expand with full debuff effect system (DOT, stat reduction, etc.)
"""

from dataclasses import dataclass, field
from typing import Optional


@dataclass
class Debuff:
    """A timed status effect applied to a character during a dungeon run."""
    id: str
    name: str
    description: str
    duration: float          # seconds remaining; -1 = permanent for this run
    hp_penalty_pct: float = 0.0    # reduces max_hp by this fraction
    mana_drain_per_sec: float = 0.0
    speed_multiplier: float = 1.0

    def tick(self, dt: float) -> bool:
        """Advance timer. Returns True if debuff has expired."""
        if self.duration < 0:
            return False
        self.duration -= dt
        return self.duration <= 0
