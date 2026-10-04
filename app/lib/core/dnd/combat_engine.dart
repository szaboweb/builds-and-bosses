import '../combat/combat_logger.dart';
import '../errors/game_error.dart';
import 'character_stats.dart';
import 'dice.dart';
import 'combat_result.dart';

export 'combat_result.dart';

/// D&D combat resolution engine.
class CombatEngine {
  static void _validateCombatants({
    required CharacterStats attacker,
    required CharacterStats defender,
  }) {
    if (attacker.isDead) {
      final exception = GameException(
        code: GameErrorCode.attackerDead,
        context: {
          'attacker': attacker.name,
          'attackerHp': attacker.currentHp,
          'defender': defender.name,
        },
      );
      CombatLogger.instance.logGameException(exception);
      throw exception;
    }
    if (defender.isDead) {
      final exception = GameException(
        code: GameErrorCode.defenderDead,
        context: {
          'attacker': attacker.name,
          'defender': defender.name,
          'defenderHp': defender.currentHp,
        },
      );
      CombatLogger.instance.logGameException(exception);
      throw exception;
    }
  }

  /// Resolves a melee weapon strike (e.g. Longsword: 1d8 + STR mod).
  static CombatResult resolveMeleeAttack({
    required CharacterStats attacker,
    required CharacterStats defender,
    int weaponDiceSides = 8,
    int diceCount = 1,
    bool advantage = false,
    bool disadvantage = false,
  }) {
    _validateCombatants(attacker: attacker, defender: defender);
    final d20 = Dice.d20(advantage: advantage, disadvantage: disadvantage);
    final totalAttack = d20 + attacker.meleeAttackBonus;
    final CombatResult result;

    // Critical Miss (Natural 1)
    if (d20 == 1) {
      result = CombatResult(
        isHit: false,
        isCritical: false,
        isCriticalMiss: true,
        rawD20Roll: d20,
        totalAttackRoll: totalAttack,
        targetAC: defender.armorClass,
        damageDealt: 0,
        description: 'NATURAL 1! CRITICAL MISS!',
      );
    } else if (d20 == 20) {
      // Critical Hit (Natural 20) — D&D 5e rule: Roll all damage dice twice!
      final baseDamage = Dice.rollMultiple(diceCount * 2, weaponDiceSides);
      final totalDamage = baseDamage + attacker.strengthMod;
      defender.takeDamage(totalDamage);

      result = CombatResult(
        isHit: true,
        isCritical: true,
        isCriticalMiss: false,
        rawD20Roll: d20,
        totalAttackRoll: totalAttack,
        targetAC: defender.armorClass,
        damageDealt: totalDamage,
        description:
            'NAT 20 CRITICAL HIT! $totalDamage dmg (2d$weaponDiceSides+${attacker.strengthMod})',
      );
    } else if (totalAttack >= defender.armorClass) {
      // Standard Hit Check vs AC
      final baseDamage = Dice.rollMultiple(diceCount, weaponDiceSides);
      final totalDamage = (baseDamage + attacker.strengthMod).clamp(1, 999);
      defender.takeDamage(totalDamage);

      result = CombatResult(
        isHit: true,
        isCritical: false,
        isCriticalMiss: false,
        rawD20Roll: d20,
        totalAttackRoll: totalAttack,
        targetAC: defender.armorClass,
        damageDealt: totalDamage,
        description:
            'HIT! (d20: $d20+${attacker.meleeAttackBonus} = $totalAttack vs AC ${defender.armorClass}) -> $totalDamage dmg',
      );
    } else {
      // Miss
      result = CombatResult(
        isHit: false,
        isCritical: false,
        isCriticalMiss: false,
        rawD20Roll: d20,
        totalAttackRoll: totalAttack,
        targetAC: defender.armorClass,
        damageDealt: 0,
        description:
            'MISS (d20: $d20+${attacker.meleeAttackBonus} = $totalAttack vs AC ${defender.armorClass})',
      );
    }

    // Automatically record structured combat outcome in the CombatLogger
    CombatLogger.instance.logCombatAttack(
      attacker: attacker,
      defender: defender,
      result: result,
    );

    return result;
  }

  static CombatResult resolveSpellAttack({
    required CharacterStats attacker,
    required CharacterStats defender,
    int spellDiceSides = 6,
    int diceCount = 1,
    bool advantage = false,
    bool disadvantage = false,
  }) {
    _validateCombatants(attacker: attacker, defender: defender);
    final d20 = Dice.d20(advantage: advantage, disadvantage: disadvantage);
    final totalAttack = d20 + attacker.spellAttackBonus;
    final CombatResult result;

    if (d20 == 1) {
      result = CombatResult(
        isHit: false,
        isCritical: false,
        isCriticalMiss: true,
        rawD20Roll: d20,
        totalAttackRoll: totalAttack,
        targetAC: defender.armorClass,
        damageDealt: 0,
        description: 'NATURAL 1! SPELL CRITICAL MISS!',
      );
    } else if (d20 == 20 || totalAttack >= defender.armorClass) {
      final critical = d20 == 20;
      final baseDamage = Dice.rollMultiple(
        critical ? diceCount * 2 : diceCount,
        spellDiceSides,
      );
      final totalDamage = (baseDamage + attacker.spellcastingAbilityMod).clamp(
        1,
        999,
      );
      defender.takeDamage(totalDamage);
      result = CombatResult(
        isHit: true,
        isCritical: critical,
        isCriticalMiss: false,
        rawD20Roll: d20,
        totalAttackRoll: totalAttack,
        targetAC: defender.armorClass,
        damageDealt: totalDamage,
        description: critical ? 'NAT 20! SPELL CRITICAL HIT!' : 'SPELL HIT!',
      );
    } else {
      result = CombatResult(
        isHit: false,
        isCritical: false,
        isCriticalMiss: false,
        rawD20Roll: d20,
        totalAttackRoll: totalAttack,
        targetAC: defender.armorClass,
        damageDealt: 0,
        description: 'SPELL MISS',
      );
    }

    CombatLogger.instance.logCombatSpell(
      attacker: attacker,
      defender: defender,
      result: result,
    );
    return result;
  }

  static CombatResult resolveRangedAttack({
    required CharacterStats attacker,
    required CharacterStats defender,
    int weaponDiceSides = 8,
    bool advantage = false,
    bool disadvantage = false,
  }) {
    _validateCombatants(attacker: attacker, defender: defender);
    final d20 = Dice.d20(advantage: advantage, disadvantage: disadvantage);
    final totalAttack = d20 + attacker.dexterityMod + attacker.proficiencyBonus;
    final critical = d20 == 20;
    final hit = critical || (d20 != 1 && totalAttack >= defender.armorClass);
    final damage = hit
        ? Dice.rollMultiple(critical ? 2 : 1, weaponDiceSides) +
              attacker.dexterityMod
        : 0;
    if (hit) defender.takeDamage(damage.clamp(1, 999));

    final result = CombatResult(
      isHit: hit,
      isCritical: critical,
      isCriticalMiss: d20 == 1,
      rawD20Roll: d20,
      totalAttackRoll: totalAttack,
      targetAC: defender.armorClass,
      damageDealt: hit ? damage.clamp(1, 999) : 0,
      description: d20 == 1
          ? 'NATURAL 1! RANGED CRITICAL MISS!'
          : critical
          ? 'NAT 20! RANGED CRITICAL HIT!'
          : hit
          ? 'RANGED HIT!'
          : 'RANGED MISS',
    );
    CombatLogger.instance.logCombatRanged(
      attacker: attacker,
      defender: defender,
      result: result,
      disadvantage: disadvantage,
    );
    return result;
  }
}
