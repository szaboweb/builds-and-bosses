"""
Combat resolver — D&D 5e-inspired attack/damage rolls.

All randomness goes through this module so it can be unit-tested
and later extended (critical hits, advantage/disadvantage, saving
throws, spell attacks).

Public API
----------
resolve_player_attack(char, boss_ac) -> AttackResult
resolve_boss_attack(boss_attack_bonus, boss_damage_die, player_ac) -> AttackResult
roll(die)          -> int          # 1..die
roll_dice(n, die)  -> int          # sum of n rolls
"""

import random
from dataclasses import dataclass
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from src.entities.character import Character


@dataclass
class AttackResult:
    hit: bool
    damage: int
    critical: bool        # natural 20
    roll: int             # the d20 value (for UI feedback)
    attack_total: int     # roll + bonus
    target_ac: int


# ---------------------------------------------------------------------------
# Dice helpers
# ---------------------------------------------------------------------------

def roll(die: int) -> int:
    """Roll 1dN."""
    return random.randint(1, die)


def roll_dice(n: int, die: int) -> int:
    """Roll NdN and sum."""
    return sum(random.randint(1, die) for _ in range(n))


# ---------------------------------------------------------------------------
# Damage dice per primary class  (weapon damage die)
# ---------------------------------------------------------------------------

# D&D 5e weapon assignments per class:
#   Fighter  -> d8  (longsword / battleaxe)
#   Paladin  -> d8  (longsword)
#   Rogue    -> d6  (shortsword / dagger) + sneak attack
#   Wizard   -> d6  (quarterstaff / cantrip: fire bolt d10 at higher levels)
#   Cleric   -> d8  (mace / warhammer)
#   Ranger   -> d8  (longbow)
#   Barbarian-> d12 (greataxe)
#   Bard     -> d6  (rapier)

CLASS_DAMAGE_DIE: dict[str, int] = {
    "fighter":   8,
    "paladin":   8,
    "rogue":     6,
    "wizard":    6,
    "cleric":    8,
    "ranger":    8,
    "barbarian": 12,
    "bard":      6,
}
DEFAULT_DAMAGE_DIE = 6


def _primary_class(char: "Character") -> str:
    """Return the class with the most levels."""
    if not char.class_levels:
        return "fighter"
    return max(char.class_levels, key=lambda c: char.class_levels[c])


def _sneak_attack_dice(char: "Character") -> int:
    """Rogue sneak attack: 1d6 per 2 rogue levels (min 1)."""
    rogue_levels = char.class_levels.get("rogue", 0)
    return max(1, rogue_levels // 2)


def _is_finesse(char: "Character") -> bool:
    """Rogue and Bard use DEX for melee damage if DEX > STR."""
    primary = _primary_class(char)
    return primary in ("rogue", "bard")


# ---------------------------------------------------------------------------
# Player attack
# ---------------------------------------------------------------------------

def resolve_player_attack(char: "Character", boss_ac: int) -> AttackResult:
    """
    Full D&D attack resolution for the player character.

    Steps:
      1. d20 + melee_attack_bonus (or spell_attack_bonus for wizard/bard)
      2. Compare vs boss_ac  (natural 1 = always miss, natural 20 = crit)
      3. On hit: damage_die + stat_mod  (crit = 2x dice, keep mod)
      4. Rogue: add sneak attack dice on any hit
    """
    from src.entities.attributes import modifier

    primary = _primary_class(char)
    attrs = char.attributes
    stats = char.stats

    # Choose attack bonus: spell casters use spell_attack_bonus
    if primary in ("wizard", "bard"):
        atk_bonus = stats.spell_attack_bonus
        stat_mod = modifier(max(attrs.INT, attrs.WIS, attrs.CHA))
    elif _is_finesse(char) and attrs.DEX > attrs.STR:
        atk_bonus = stats.melee_attack_bonus  # already max(STR,DEX)+pb
        stat_mod = modifier(attrs.DEX)
    else:
        atk_bonus = stats.melee_attack_bonus
        stat_mod = modifier(attrs.STR)

    d20 = roll(20)
    attack_total = d20 + atk_bonus
    critical = (d20 == 20)
    auto_miss = (d20 == 1)

    hit = (not auto_miss) and (critical or attack_total >= boss_ac)

    if not hit:
        return AttackResult(hit=False, damage=0, critical=False,
                            roll=d20, attack_total=attack_total, target_ac=boss_ac)

    # Damage roll
    dmg_die = CLASS_DAMAGE_DIE.get(primary, DEFAULT_DAMAGE_DIE)
    dice_count = 2 if critical else 1
    raw_dmg = roll_dice(dice_count, dmg_die)

    # Sneak attack (rogue)
    sneak = 0
    if "rogue" in char.class_levels:
        sa_dice = _sneak_attack_dice(char)
        sneak = roll_dice(sa_dice * (2 if critical else 1), 6)

    # Paladin divine smite (simplified: if mana available, +2d8 radiant)
    smite = 0
    if primary == "paladin" and char.stats.current_mana >= 15:
        smite_dice = 2 if not critical else 4
        smite = roll_dice(smite_dice, 8)
        char.stats.current_mana = max(0, char.stats.current_mana - 15)

    total_dmg = max(1, raw_dmg + stat_mod + sneak + smite)

    return AttackResult(hit=True, damage=total_dmg, critical=critical,
                        roll=d20, attack_total=attack_total, target_ac=boss_ac)


# ---------------------------------------------------------------------------
# Boss attack
# ---------------------------------------------------------------------------

def resolve_boss_attack(
    boss_attack_bonus: int,
    boss_damage_die: int,
    boss_damage_count: int,
    player_ac: int,
) -> AttackResult:
    """
    D&D attack roll for the boss.

    Natural 1 = auto miss, natural 20 = crit (2x dice).
    """
    d20 = roll(20)
    attack_total = d20 + boss_attack_bonus
    critical = (d20 == 20)
    auto_miss = (d20 == 1)

    hit = (not auto_miss) and (critical or attack_total >= player_ac)

    if not hit:
        return AttackResult(hit=False, damage=0, critical=False,
                            roll=d20, attack_total=attack_total, target_ac=player_ac)

    dice_count = boss_damage_count * 2 if critical else boss_damage_count
    dmg = max(1, roll_dice(dice_count, boss_damage_die) + (boss_attack_bonus // 2))

    return AttackResult(hit=True, damage=dmg, critical=critical,
                        roll=d20, attack_total=attack_total, target_ac=player_ac)
