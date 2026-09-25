import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/actions/game_action.dart';
import '../../core/dnd/character_stats.dart';
import '../../core/dnd/combat_engine.dart';
import '../../core/dnd/dice.dart';
import 'arena_map_component.dart';
import 'dummy_enemy_component.dart';
import 'floating_combat_text.dart';
import 'projectile_component.dart';
import '../../core/combat/combat_logger.dart';

/// Side-view Platformer Fighter Protagonist with gravity, jump physics,
/// platform landing, dynamic ground shadow, and Tactical Mode execution.
class PlayerComponent extends PositionComponent with HasGameReference {
  CharacterStats stats;
  final Rect movementBounds;

  // Realtime physics & movement — dynamically scaled by stats & GameRulesConfig
  Vector2 velocity = Vector2.zero();
  double get moveSpeed => stats.moveSpeed;
  double get jumpVelocity => stats.jumpVelocity;
  double get gravity => stats.config.physics.baseGravity;

  // Free vertical movement ("flight"): -1 up, 0 idle, +1 down. SPACE stays the only jump trigger.
  double verticalFlightInput = 0.0;

  bool isOnGround = true;
  double _dropThroughTimer = 0.0;

  // Execution state (Tactical Mode)
  bool isExecutingPlan = false;
  List<GameAction> _currentQueue = [];
  int _executingIndex = 0;
  double _actionTimer = 0.0;
  Vector2? _moveTarget;
  VoidCallback? _onPlanFinished;

  // Visuals & Animation
  Sprite? sprite;
  bool isFacingLeft = false;
  double _slashVfxTimer = 0.0;
  Vector2? _slashTargetPos;
  double _movementAnimationTime = 0.0;

  PlayerComponent({
    required Vector2 position,
    CharacterStats? stats,
    required this.movementBounds,
  }) : stats = stats ?? CharacterStats.fighterProtagonist(),
       super(position: position, size: Vector2(48, 52), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    try {
      final image = await game.images.load('characters/fighter.png');
      sprite = Sprite(
        image,
        srcPosition: Vector2(0, 0),
        srcSize: Vector2(48, 48),
      );
    } catch (_) {
      sprite = null;
    }
  }

  /// Update character stats dynamically (e.g. from Character Builder / Tervezőasztal)
  void updateStats(CharacterStats newStats) {
    stats = newStats;
  }

  /// Perform a jump if currently on the ground or a platform.
  bool jump() {
    if (isOnGround && !isExecutingPlan) {
      velocity.y = jumpVelocity;
      isOnGround = false;
      return true;
    }
    return false;
  }

  /// Drop down through a semi-solid platform if not on the main ground floor.
  void dropDown() {
    if (isOnGround && !isExecutingPlan) {
      final arena = game.world.children
          .whereType<ArenaMapComponent>()
          .firstOrNull;
      if (arena != null && (position.y + size.y / 2) < arena.groundY - 10) {
        position.y += 8.0;
        isOnGround = false;
        _dropThroughTimer = 0.28;
      }
    }
  }

  /// Start executing the queued planned actions in sequence.
  void executePlan(List<GameAction> actions, VoidCallback onFinished) {
    if (actions.isEmpty) {
      onFinished();
      return;
    }
    isExecutingPlan = true;
    _currentQueue = List.from(actions);
    _executingIndex = 0;
    _actionTimer = 0.0;
    _moveTarget = null;
    _onPlanFinished = onFinished;
    _startCurrentAction();
  }

  void _startCurrentAction() {
    if (_executingIndex >= _currentQueue.length) {
      isExecutingPlan = false;
      _onPlanFinished?.call();
      return;
    }

    final action = _currentQueue[_executingIndex];
    CombatLogger.instance.logTacticalAction(
      eventType: 'EXECUTED',
      action: action,
      spentAP: action.apCost,
      remainingAP: 0,
    );

    if (action is MoveAction) {
      _moveTarget = action.targetPosition.clone();
      _clampTargetToArena(_moveTarget!);
      isFacingLeft = _moveTarget!.x < position.x;
    } else if (action is DashAction) {
      _moveTarget = action.targetPosition.clone();
      _clampTargetToArena(_moveTarget!);
      isFacingLeft = _moveTarget!.x < position.x;
    } else if (action is SlashAction) {
      _slashTargetPos = action.targetPosition.clone();
      isFacingLeft = _slashTargetPos!.x < position.x;
      _slashVfxTimer = 0.35;
      _resolveSlash(action.targetPosition);
    } else if (action is SpellAction) {
      _slashTargetPos = action.targetPosition.clone();
      isFacingLeft = _slashTargetPos!.x < position.x;
      _slashVfxTimer = 0.35;
      _resolveSpell(action.targetPosition, action.knockback);
    } else if (action is RangedAction) {
      _slashTargetPos = action.targetPosition.clone();
      isFacingLeft = _slashTargetPos!.x < position.x;
      game.world.add(
        ProjectileComponent(
          position: position.clone(),
          targetPosition: action.targetPosition.clone(),
          color: const Color(0xFFFFD54F),
        ),
      );
      _resolveRanged(action.targetPosition);
    } else if (action is HealAction) {
      _resolveSecondWind();
    }
  }

  void _clampTargetToArena(Vector2 target) {
    final arena = game.world.children
        .whereType<ArenaMapComponent>()
        .firstOrNull;
    final leftLimit = arena != null
        ? arena.leftWallX + 24
        : movementBounds.left + 24;
    final rightLimit = arena != null
        ? arena.rightWallX - 24
        : movementBounds.right - 24;
    final bottomLimit = arena != null
        ? arena.groundY - size.y / 2
        : movementBounds.bottom - 24;

    target.x = target.x.clamp(leftLimit, rightLimit);
    target.y = target.y.clamp(40.0, bottomLimit);
  }

  void _resolveSlash(Vector2 targetPos) {
    if (!canReachMelee(targetPos)) {
      CombatLogger.instance.logWarning(
        'COMBAT',
        '${stats.name} attempted a melee attack out of range.',
      );
      game.world.add(
        FloatingCombatText(
          text: 'OUT OF RANGE',
          position: position.clone() + Vector2(0, -32),
          style: CombatTextStyle.info,
        ),
      );
      return;
    }

    final enemies = game.world.children.whereType<DummyEnemyComponent>();
    DummyEnemyComponent? targetEnemy;
    double closestDist = stats.meleeRange;

    for (final e in enemies) {
      final d = e.position.distanceTo(targetPos);
      if (d < closestDist) {
        closestDist = d;
        targetEnemy = e;
      }
    }

    if (targetEnemy != null && !targetEnemy.stats.isDead) {
      final result = CombatEngine.resolveMeleeAttack(
        attacker: stats,
        defender: targetEnemy.stats,
      );

      targetEnemy.triggerHitReaction();
      targetEnemy.triggerStagger(stats.meleeStagger);

      if (result.isCritical) {
        game.world.add(
          FloatingCombatText(
            text: 'CRIT! ${result.damageDealt}',
            position: targetEnemy.position.clone() + Vector2(0, -28),
            style: CombatTextStyle.critical,
          ),
        );
      } else if (result.isHit) {
        game.world.add(
          FloatingCombatText(
            text: '-${result.damageDealt}',
            position: targetEnemy.position.clone() + Vector2(0, -28),
            style: CombatTextStyle.damage,
          ),
        );
      } else {
        game.world.add(
          FloatingCombatText(
            text: 'MISS',
            position: targetEnemy.position.clone() + Vector2(0, -28),
            style: CombatTextStyle.miss,
          ),
        );
      }
    } else {
      CombatLogger.instance.log(
        level: LogLevel.info,
        category: 'COMBAT',
        message:
            '${stats.name} slashed at target coordinates $targetPos (No target in range)',
        data: {'targetX': targetPos.x, 'targetY': targetPos.y},
      );
      game.world.add(
        FloatingCombatText(
          text: 'SWING!',
          position: targetPos.clone(),
          style: CombatTextStyle.info,
        ),
      );
    }
  }

  bool canReachMelee(Vector2 targetPosition) {
    final delta = targetPosition - position;
    final verticalRange =
        stats.meleeRange * stats.config.combat.meleeVerticalTolerance;
    return delta.x.abs() <= stats.meleeRange && delta.y.abs() <= verticalRange;
  }

  void _resolveSpell(Vector2 targetPos, double knockback) {
    final spellDistance = position.distanceTo(targetPos);
    if (spellDistance > stats.config.combat.spellRange) {
      _showCombatRangeMessage('SPELL OUT OF RANGE');
      return;
    }
    final enemies = game.world.children.whereType<DummyEnemyComponent>();
    DummyEnemyComponent? targetEnemy;
    double closestDistance = stats.config.combat.spellRange;
    for (final enemy in enemies) {
      final distance = enemy.position.distanceTo(targetPos);
      if (distance < closestDistance) {
        closestDistance = distance;
        targetEnemy = enemy;
      }
    }
    if (targetEnemy == null || targetEnemy.stats.isDead) return;

    final result = CombatEngine.resolveSpellAttack(
      attacker: stats,
      defender: targetEnemy.stats,
    );
    if (result.isHit) {
      targetEnemy.triggerHitReaction();
      final totalKnockback =
          knockback + result.damageDealt * stats.config.combat.spellKnockbackPerDamage;
      if (totalKnockback > 0) {
        final direction = (targetEnemy.position - position).normalized();
        targetEnemy.position += direction * totalKnockback;
      }
    }
  }

  void _resolveRanged(Vector2 targetPos) {
    final rangedDistance = position.distanceTo(targetPos);
    if (rangedDistance > stats.rangedLongRange) {
      _showCombatRangeMessage('RANGED OUT OF RANGE');
      return;
    }
    final disadvantage = rangedDistance > stats.rangedNormalRange;
    final enemies = game.world.children.whereType<DummyEnemyComponent>();
    DummyEnemyComponent? targetEnemy;
    var closestDistance = stats.rangedLongRange;
    for (final enemy in enemies) {
      final distance = enemy.position.distanceTo(targetPos);
      if (distance < closestDistance) {
        closestDistance = distance;
        targetEnemy = enemy;
      }
    }
    if (targetEnemy == null || targetEnemy.stats.isDead) return;
    final result = CombatEngine.resolveRangedAttack(
      attacker: stats,
      defender: targetEnemy.stats,
      disadvantage: disadvantage,
    );
    if (result.isHit) {
      targetEnemy.triggerHitReaction();
      if (stats.rangedKnockback > 0) {
        final direction = (targetEnemy.position - position).normalized();
        targetEnemy.position += direction * stats.rangedKnockback;
      }
    }
  }

  void _showCombatRangeMessage(String message) {
    game.world.add(
      FloatingCombatText(
        text: message,
        position: position.clone() + Vector2(0, -32),
        style: CombatTextStyle.info,
      ),
    );
  }

  void _resolveSecondWind() {
    final healAmount = Dice.d10() + stats.level + stats.constitutionMod;
    stats.heal(healAmount);

    CombatLogger.instance.logCombatHeal(
      target: stats,
      healAmount: healAmount,
      abilityName: 'Second Wind',
    );

    game.world.add(
      FloatingCombatText(
        text: '+$healAmount HP',
        position: position.clone() + Vector2(0, -32),
        style: CombatTextStyle.heal,
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _movementAnimationTime += dt;

    if (_slashVfxTimer > 0) {
      _slashVfxTimer = max(0.0, _slashVfxTimer - dt);
    }
    if (_dropThroughTimer > 0) {
      _dropThroughTimer = max(0.0, _dropThroughTimer - dt);
    }

    if (isExecutingPlan) {
      _updateExecution(dt);
    } else {
      _updatePlatformerPhysics(dt);
    }
  }

  void _updatePlatformerPhysics(double dt) {
    final arena = game.world.children
        .whereType<ArenaMapComponent>()
        .firstOrNull;
    final groundY = arena?.groundY ?? movementBounds.bottom;
    final leftX = arena != null
        ? arena.leftWallX + size.x / 2
        : movementBounds.left + size.x / 2;
    final rightX = arena != null
        ? arena.rightWallX - size.x / 2
        : movementBounds.right - size.x / 2;
    final topY = arena != null ? 20.0 : movementBounds.top + 20.0;

    final isFlying = verticalFlightInput != 0;

    if (isFlying) {
      // Free vertical flight overrides gravity while held.
      velocity.y = 0;
    } else {
      // Apply gravity
      velocity.y += gravity * dt;
      velocity.y = velocity.y.clamp(-650.0, 750.0);
    }

    // Apply horizontal movement
    if (velocity.x != 0) {
      position.x += velocity.x * moveSpeed * dt;
      isFacingLeft = velocity.x < 0;
      position.x = position.x.clamp(leftX, rightX);
    }

    // Apply vertical movement & collisions
    final prevFeetY = position.y + size.y / 2;
    if (isFlying) {
      position.y += verticalFlightInput * moveSpeed * dt;
      position.y = position.y.clamp(topY, groundY - size.y / 2);
    } else {
      position.y += velocity.y * dt;
    }
    final currentFeetY = position.y + size.y / 2;

    isOnGround = false;

    // 1. Check solid ground landing
    if (currentFeetY >= groundY) {
      position.y = groundY - size.y / 2;
      velocity.y = 0;
      isOnGround = true;
      return;
    }

    // 2. Check elevated platform landings (only when falling downward, not flying, and not dropping through)
    if (!isFlying &&
        velocity.y >= 0 &&
        _dropThroughTimer <= 0 &&
        arena != null) {
      for (final plat in arena.platforms) {
        if (position.x >= plat.left - 10 && position.x <= plat.right + 10) {
          // If feet crossed the platform top threshold
          if (prevFeetY <= plat.top + 8 && currentFeetY >= plat.top) {
            position.y = plat.top - size.y / 2;
            velocity.y = 0;
            isOnGround = true;
            return;
          }
        }
      }
    }
  }

  void _updateExecution(double dt) {
    final action = _currentQueue[_executingIndex];

    if (action is MoveAction || action is DashAction) {
      final isDash = action is DashAction;
      final speed = isDash ? moveSpeed * 3.8 : moveSpeed * 2.4;

      if (_moveTarget != null) {
        final dist = position.distanceTo(_moveTarget!);
        final step = speed * dt;

        if (dist <= step) {
          position.setFrom(_moveTarget!);
          _moveTarget = null;
          _executingIndex++;
          _startCurrentAction();
        } else {
          final dir = (_moveTarget! - position).normalized();
          position += dir * step;
        }
      }
    } else {
      _actionTimer += dt;
      if (_actionTimer >= 0.35) {
        _actionTimer = 0.0;
        _executingIndex++;
        _startCurrentAction();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 1. Dynamic Landing Shadow on surface below
    _renderDynamicShadow(canvas);

    // 2. Character Model
    canvas.save();
    if (isFacingLeft) {
      canvas.scale(-1, 1);
      canvas.translate(-size.x, 0);
    }

    if (sprite != null) {
      sprite!.render(canvas, size: size);
    } else {
      _renderProceduralSideViewFighter(canvas);
    }
    _renderClassWeapon(canvas);

    canvas.restore();

    // 3. Render Slash VFX arc
    if (_slashVfxTimer > 0 && _slashTargetPos != null) {
      final arcPaint = Paint()
        ..color = const Color(0xFF00E5FF)
            .withValues(alpha: _slashVfxTimer / 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;

      final diff = _slashTargetPos! - position;
      final localTarget = Offset(size.x / 2 + diff.x, size.y / 2 + diff.y);
      canvas.drawLine(Offset(size.x / 2, size.y / 2), localTarget, arcPaint);
    }
  }

  void _renderClassWeapon(Canvas canvas) {
    final isAttacking = _slashVfxTimer > 0;
    final attackProgress = isAttacking ? 1.0 - (_slashVfxTimer / 0.35) : 0.0;
    final walkSwing = isOnGround && velocity.x != 0
        ? sin(_movementAnimationTime * 12.0) * 0.18
        : 0.0;
    final swing = isAttacking ? sin(attackProgress * pi) * 1.15 : walkSwing;
    final hand = Offset(31, 27);
    final direction = isFacingLeft ? -1.0 : 1.0;
    final weaponPaint = Paint()
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.translate(hand.dx, hand.dy);
    canvas.rotate(direction * swing);
    canvas.translate(-hand.dx, -hand.dy);

    canvas.drawLine(
      Offset(hand.dx - direction * 2, hand.dy - 1),
      Offset(hand.dx + direction * 4, hand.dy + 2),
      Paint()..color = const Color(0xFFD49A62),
    );

    switch (stats.classId) {
      case 'rogue':
        weaponPaint.color = const Color(0xFFE0E0E0);
        canvas.drawLine(
          hand,
          Offset(hand.dx + direction * 13, hand.dy - 10),
          weaponPaint,
        );
        canvas.drawLine(
          Offset(hand.dx + direction * 2, hand.dy + 1),
          Offset(hand.dx + direction * 5, hand.dy + 4),
          Paint()
            ..color = const Color(0xFFB8784F)
            ..strokeWidth = 2,
        );
        break;
      case 'cleric':
        weaponPaint
          ..color = const Color(0xFFB8784F)
          ..strokeWidth = 3;
        canvas.drawLine(
          hand,
          Offset(hand.dx + direction * 2, hand.dy - 22),
          weaponPaint,
        );
        canvas.drawLine(
          Offset(hand.dx + direction * 2, hand.dy - 24),
          Offset(hand.dx + direction * 2, hand.dy - 19),
          Paint()
            ..color = const Color(0xFFFFD54F)
            ..strokeWidth = 2,
        );
        canvas.drawLine(
          Offset(hand.dx - direction * 1, hand.dy - 22),
          Offset(hand.dx + direction * 5, hand.dy - 22),
          Paint()
            ..color = const Color(0xFFFFD54F)
            ..strokeWidth = 2,
        );
        break;
      case 'fighter':
      default:
        weaponPaint.color = const Color(0xFFE0E0E0);
        canvas.drawLine(
          hand,
          Offset(hand.dx + direction * 17, hand.dy - 21),
          weaponPaint,
        );
        canvas.drawLine(
          Offset(hand.dx + direction * 1, hand.dy - 1),
          Offset(hand.dx + direction * 7, hand.dy + 5),
          Paint()
            ..color = const Color(0xFFFFD54F)
            ..strokeWidth = 2.5,
        );
        break;
    }
    canvas.restore();
  }

  void _renderDynamicShadow(Canvas canvas) {
    final arena = game.world.children
        .whereType<ArenaMapComponent>()
        .firstOrNull;
    if (arena == null) return;

    final feetY = position.y + size.y / 2;
    final surfaceY = arena.getSurfaceYBelow(position);
    final heightAboveSurface = max(0.0, surfaceY - feetY);

    final shadowRatio = (1.0 - (heightAboveSurface / 260.0)).clamp(0.3, 1.0);
    final shadowAlpha = (0.45 * shadowRatio).clamp(0.08, 0.45);

    final shadowCenter = Offset(
      size.x / 2,
      size.y / 2 + heightAboveSurface + 2,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: shadowCenter,
        width: 32 * shadowRatio,
        height: 8 * shadowRatio,
      ),
      Paint()..color = Colors.black.withValues(alpha: shadowAlpha),
    );
  }

  void _renderProceduralSideViewFighter(Canvas canvas) {
    // Flowing Cape (Back)
    final capePath = Path()
      ..moveTo(12, 18)
      ..lineTo(2, 42)
      ..lineTo(16, 44)
      ..lineTo(20, 22)
      ..close();
    canvas.drawPath(capePath, Paint()..color = const Color(0xFFB71C1C));

    // Plate Leg Greaves
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(16, 36, 7, 14),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF455A64),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(25, 36, 7, 14),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF37474F),
    );

    // Torso Plate Armor & Belt
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(14, 18, 20, 20),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF78909C),
    );
    // Gold Belt
    canvas.drawRect(
      const Rect.fromLTWH(14, 34, 20, 4),
      Paint()..color = const Color(0xFFFFD54F),
    );

    // Helmet & Visor
    canvas.drawCircle(
      const Offset(24, 14),
      9,
      Paint()..color = const Color(0xFF546E7A),
    );
    // Gold Visor slit
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(24, 12, 9, 3),
        const Radius.circular(1),
      ),
      Paint()..color = const Color(0xFFFFD54F),
    );

    // Left Arm with Heavy Shield
    canvas.drawOval(
      const Rect.fromLTWH(10, 19, 10, 18),
      Paint()..color = const Color(0xFF1E88E5),
    );
    canvas.drawOval(
      const Rect.fromLTWH(12, 21, 6, 14),
      Paint()
        ..color = const Color(0xFFFFD54F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Right Arm with Broadsword
    final bladePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(32, 26), const Offset(44, 8), bladePaint);

    // Sword Crossguard
    canvas.drawLine(
      const Offset(28, 24),
      const Offset(35, 29),
      Paint()
        ..color = const Color(0xFFFFD54F)
        ..strokeWidth = 2.5,
    );
  }
}
