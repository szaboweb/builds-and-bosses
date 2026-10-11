import 'package:flame/components.dart';

import '../../core/combat/combat_logger.dart';
import '../../core/dnd/character_stats.dart';
import '../../core/dnd/combat_engine.dart';
import '../../core/dnd/dice.dart';
import '../../core/physics/displacement_resolver.dart';
import 'base_enemy_component.dart';
import 'floating_combat_text.dart';

/// Owns combat action resolution, melee/spell/ranged damage calculation,
/// knockback application, and physical contact pushing for the player character.
/// Extracted from PlayerComponent per docs/ARCHITECTURE.md.
class PlayerCombatController {
  /// Checks whether [targetPosition] is within melee reach of [playerPosition].
  bool canReachMelee({
    required Vector2 playerPosition,
    required Vector2 targetPosition,
    required CharacterStats stats,
  }) {
    final delta = targetPosition - playerPosition;
    final verticalRange =
        stats.meleeRange * stats.config.combat.meleeVerticalTolerance;
    return delta.x.abs() <= stats.meleeRange && delta.y.abs() <= verticalRange;
  }

  /// Resolves a melee slash attack against enemies adjacent to [targetPos].
  void resolveSlash({
    required Vector2 targetPos,
    required Vector2 playerPosition,
    required CharacterStats stats,
    required Iterable<BaseEnemyComponent> enemies,
    required void Function(Component) onSpawnComponent,
  }) {
    if (!canReachMelee(
      playerPosition: playerPosition,
      targetPosition: targetPos,
      stats: stats,
    )) {
      CombatLogger.instance.logWarning(
        'COMBAT',
        '${stats.name} attempted a melee attack out of range.',
      );
      onSpawnComponent(
        FloatingCombatText(
          text: 'OUT OF RANGE',
          position: playerPosition.clone() + Vector2(0, -32),
          style: CombatTextStyle.info,
        ),
      );
      return;
    }

    final targetEnemy = _findClosestEnemy(enemies, targetPos, stats.meleeRange);
    if (targetEnemy != null && !targetEnemy.stats.isDead) {
      _applyMeleeHit(
        attacker: stats,
        targetEnemy: targetEnemy,
        playerPosition: playerPosition,
        onSpawnComponent: onSpawnComponent,
      );
    } else {
      CombatLogger.instance.log(
        level: LogLevel.info,
        category: 'COMBAT',
        message:
            '${stats.name} slashed at target coordinates $targetPos (No target in range)',
        data: {'targetX': targetPos.x, 'targetY': targetPos.y},
      );
      onSpawnComponent(
        FloatingCombatText(
          text: 'SWING!',
          position: targetPos.clone(),
          style: CombatTextStyle.info,
        ),
      );
    }
  }

  BaseEnemyComponent? _findClosestEnemy(
    Iterable<BaseEnemyComponent> enemies,
    Vector2 targetPos,
    double maxRange,
  ) {
    BaseEnemyComponent? closest;
    double closestDist = maxRange;
    for (final e in enemies) {
      final d = e.position.distanceTo(targetPos);
      if (d < closestDist) {
        closestDist = d;
        closest = e;
      }
    }
    return closest;
  }

  void _applyMeleeHit({
    required CharacterStats attacker,
    required BaseEnemyComponent targetEnemy,
    required Vector2 playerPosition,
    required void Function(Component) onSpawnComponent,
  }) {
    final result = CombatEngine.resolveMeleeAttack(
      attacker: attacker,
      defender: targetEnemy.stats,
    );

    targetEnemy.triggerHitReaction();
    targetEnemy.triggerStagger(attacker.meleeStagger);

    if (attacker.meleeKnockback > 0) {
      final pushDir = (targetEnemy.position.x >= playerPosition.x) ? 1.0 : -1.0;
      targetEnemy.applyKnockback(forceX: pushDir * attacker.meleeKnockback);
    }

    final textStyle = result.isCritical
        ? CombatTextStyle.critical
        : (result.isHit ? CombatTextStyle.damage : CombatTextStyle.miss);
    final text = result.isCritical
        ? 'CRIT! ${result.damageDealt}'
        : (result.isHit ? '-${result.damageDealt}' : 'MISS');

    onSpawnComponent(
      FloatingCombatText(
        text: text,
        position: targetEnemy.position.clone() + Vector2(0, -28),
        style: textStyle,
      ),
    );
  }

  /// Resolves a magical spell attack against the foe closest to [targetPos].
  void resolveSpell({
    required Vector2 targetPos,
    required Vector2 playerPosition,
    required CharacterStats stats,
    required double knockback,
    required Iterable<BaseEnemyComponent> enemies,
    required void Function(Component) onSpawnComponent,
  }) {
    final spellDistance = playerPosition.distanceTo(targetPos);
    if (spellDistance > stats.spellRange) {
      onSpawnComponent(
        FloatingCombatText(
          text: 'SPELL OUT OF RANGE',
          position: playerPosition.clone() + Vector2(0, -32),
          style: CombatTextStyle.info,
        ),
      );
      return;
    }

    final targetEnemy = _findClosestEnemy(enemies, targetPos, stats.spellRange);
    if (targetEnemy == null || targetEnemy.stats.isDead) return;

    final result = CombatEngine.resolveSpellAttack(
      attacker: stats,
      defender: targetEnemy.stats,
    );
    if (result.isHit) {
      targetEnemy.triggerHitReaction();
      final totalKnockback =
          knockback +
          result.damageDealt * stats.config.combat.spellKnockbackPerDamage;
      if (totalKnockback > 0) {
        final pushDir = (targetEnemy.position.x >= playerPosition.x)
            ? 1.0
            : -1.0;
        targetEnemy.applyKnockback(forceX: pushDir * totalKnockback * 8.0);
      }
    }
  }

  /// Resolves a ranged weapon attack against the foe closest to [targetPos].
  void resolveRanged({
    required Vector2 targetPos,
    required Vector2 playerPosition,
    required CharacterStats stats,
    required Iterable<BaseEnemyComponent> enemies,
    required void Function(Component) onSpawnComponent,
  }) {
    final rangedDistance = playerPosition.distanceTo(targetPos);
    if (rangedDistance > stats.rangedLongRange) {
      onSpawnComponent(
        FloatingCombatText(
          text: 'RANGED OUT OF RANGE',
          position: playerPosition.clone() + Vector2(0, -32),
          style: CombatTextStyle.info,
        ),
      );
      return;
    }
    final disadvantage = rangedDistance > stats.rangedNormalRange;
    final targetEnemy = _findClosestEnemy(
      enemies,
      targetPos,
      stats.rangedLongRange,
    );
    if (targetEnemy == null || targetEnemy.stats.isDead) return;

    final result = CombatEngine.resolveRangedAttack(
      attacker: stats,
      defender: targetEnemy.stats,
      disadvantage: disadvantage,
    );
    if (result.isHit) {
      targetEnemy.triggerHitReaction();
      if (stats.rangedKnockback > 0) {
        final pushDir = (targetEnemy.position.x >= playerPosition.x)
            ? 1.0
            : -1.0;
        targetEnemy.applyKnockback(
          forceX: pushDir * stats.rangedKnockback * 8.0,
        );
      }
    }
  }

  /// Resolves the Fighter's Second Wind healing ability.
  void resolveSecondWind({
    required CharacterStats stats,
    required Vector2 playerPosition,
    required void Function(Component) onSpawnComponent,
  }) {
    final healAmount = Dice.d10() + stats.level + stats.constitutionMod;
    stats.heal(healAmount);

    CombatLogger.instance.logCombatHeal(
      target: stats,
      healAmount: healAmount,
      abilityName: 'Second Wind',
    );

    onSpawnComponent(
      FloatingCombatText(
        text: '+$healAmount HP',
        position: playerPosition.clone() + Vector2(0, -32),
        style: CombatTextStyle.heal,
      ),
    );
  }

  bool _canCollideWithEnemy(
    BaseEnemyComponent enemy,
    double playerFeet,
    double playerHead,
  ) {
    if (enemy.stats.isDead) return false;
    final enemyTop = enemy.position.y - enemy.size.y / 2;
    final enemyBottom = enemy.position.y + enemy.size.y / 2;
    if (enemy.isRideable && playerFeet <= enemyTop + 8.0) return false;
    if (playerFeet > enemyBottom + 4.0) return false;
    return playerFeet > enemyTop && playerHead < enemyBottom;
  }

  /// Resolves physical body contact between moving player and adjacent enemies.
  /// Strong characters (STR >= 16) push/shove enemies; all characters are blocked
  /// from walking through solid enemy bodies unless in gaseous form.
  void resolveEnemyContactPush({
    required Vector2 playerPosition,
    required Vector2 playerSize,
    required CharacterStats stats,
    required double playerVelocityX,
    required double dt,
    required Iterable<BaseEnemyComponent> enemies,
    bool isGaseous = false,
  }) {
    if (playerVelocityX == 0 || isGaseous) return;

    final playerFeet = playerPosition.y + playerSize.y / 2;
    final playerHead = playerPosition.y - playerSize.y / 2;
    const resolver = PhysicalContestResolver();

    for (final enemy in enemies) {
      if (!_canCollideWithEnemy(enemy, playerFeet, playerHead)) continue;

      final dx = enemy.position.x - playerPosition.x;
      final combinedHalfWidth = (playerSize.x + enemy.size.x) / 2 - 4.0;

      if (dx.abs() > combinedHalfWidth) continue;
      if (playerVelocityX * dx <= 0) continue;

      final pushDir = dx > 0 ? 1.0 : -1.0;

      final outcome = resolver.resolve(
        PhysicalContestRequest(
          moverStr: stats.strength,
          targetStr: enemy.stats.strength,
          moverVelocity: playerVelocityX * stats.moveSpeed,
          targetVelocity: enemy.velocity.x,
          isRideable: enemy.isRideable,
          isGaseous: isGaseous,
          dt: dt,
        ),
      );

      if (outcome.canShoveTarget && outcome.targetDisplacement != 0) {
        enemy.pushBy(outcome.targetDisplacement);
      }

      if (outcome.isBodyBlocked) {
        playerPosition.x = enemy.position.x - pushDir * combinedHalfWidth;
      }
    }
  }
}
