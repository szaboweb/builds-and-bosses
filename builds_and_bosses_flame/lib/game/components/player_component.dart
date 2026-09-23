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

  PlayerComponent({
    required Vector2 position,
    CharacterStats? stats,
    required this.movementBounds,
  })  : stats = stats ?? CharacterStats.fighterProtagonist(),
        super(
          position: position,
          size: Vector2(48, 52),
          anchor: Anchor.center,
        );

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
      final arena = game.children.whereType<ArenaMapComponent>().firstOrNull;
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
    } else if (action is HealAction) {
      _resolveSecondWind();
    }
  }

  void _clampTargetToArena(Vector2 target) {
    final arena = game.children.whereType<ArenaMapComponent>().firstOrNull;
    final leftLimit = arena != null ? arena.leftWallX + 24 : movementBounds.left + 24;
    final rightLimit = arena != null ? arena.rightWallX - 24 : movementBounds.right - 24;
    final bottomLimit = arena != null ? arena.groundY - size.y / 2 : movementBounds.bottom - 24;

    target.x = target.x.clamp(leftLimit, rightLimit);
    target.y = target.y.clamp(40.0, bottomLimit);
  }

  void _resolveSlash(Vector2 targetPos) {
    final enemies = game.children.whereType<DummyEnemyComponent>();
    DummyEnemyComponent? targetEnemy;
    double closestDist = 110.0;

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

      if (result.isCritical) {
        game.add(
          FloatingCombatText(
            text: 'CRIT! ${result.damageDealt}',
            position: targetEnemy.position.clone() + Vector2(0, -28),
            style: CombatTextStyle.critical,
          ),
        );
      } else if (result.isHit) {
        game.add(
          FloatingCombatText(
            text: '-${result.damageDealt}',
            position: targetEnemy.position.clone() + Vector2(0, -28),
            style: CombatTextStyle.damage,
          ),
        );
      } else {
        game.add(
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
        message: '${stats.name} slashed at target coordinates $targetPos (No target in range)',
        data: {'targetX': targetPos.x, 'targetY': targetPos.y},
      );
      game.add(
        FloatingCombatText(
          text: 'SWING!',
          position: targetPos.clone(),
          style: CombatTextStyle.info,
        ),
      );
    }
  }

  void _resolveSecondWind() {
    final healAmount = Dice.d10() + stats.level + stats.constitutionMod;
    stats.heal(healAmount);

    CombatLogger.instance.logCombatHeal(
      target: stats,
      healAmount: healAmount,
      abilityName: 'Second Wind',
    );

    game.add(
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
    final arena = game.children.whereType<ArenaMapComponent>().firstOrNull;
    final groundY = arena?.groundY ?? movementBounds.bottom;
    final leftX = arena != null ? arena.leftWallX + size.x / 2 : movementBounds.left + size.x / 2;
    final rightX = arena != null ? arena.rightWallX - size.x / 2 : movementBounds.right - size.x / 2;

    // Apply gravity
    velocity.y += gravity * dt;
    velocity.y = velocity.y.clamp(-650.0, 750.0);

    // Apply horizontal movement
    if (velocity.x != 0) {
      position.x += velocity.x * moveSpeed * dt;
      isFacingLeft = velocity.x < 0;
      position.x = position.x.clamp(leftX, rightX);
    }

    // Apply vertical movement & collisions
    final prevFeetY = position.y + size.y / 2;
    position.y += velocity.y * dt;
    final currentFeetY = position.y + size.y / 2;

    isOnGround = false;

    // 1. Check solid ground landing
    if (currentFeetY >= groundY) {
      position.y = groundY - size.y / 2;
      velocity.y = 0;
      isOnGround = true;
      return;
    }

    // 2. Check elevated platform landings (only when falling downward and not dropping through)
    if (velocity.y >= 0 && _dropThroughTimer <= 0 && arena != null) {
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

    canvas.restore();

    // 3. Render Slash VFX arc
    if (_slashVfxTimer > 0 && _slashTargetPos != null) {
      final arcPaint = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: _slashVfxTimer / 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;

      final diff = _slashTargetPos! - position;
      final localTarget = Offset(size.x / 2 + diff.x, size.y / 2 + diff.y);
      canvas.drawLine(
        Offset(size.x / 2, size.y / 2),
        localTarget,
        arcPaint,
      );
    }
  }

  void _renderDynamicShadow(Canvas canvas) {
    final arena = game.children.whereType<ArenaMapComponent>().firstOrNull;
    if (arena == null) return;

    final feetY = position.y + size.y / 2;
    final surfaceY = arena.getSurfaceYBelow(position);
    final heightAboveSurface = max(0.0, surfaceY - feetY);

    final shadowRatio = (1.0 - (heightAboveSurface / 260.0)).clamp(0.3, 1.0);
    final shadowAlpha = (0.45 * shadowRatio).clamp(0.08, 0.45);

    final shadowCenter = Offset(size.x / 2, size.y / 2 + heightAboveSurface + 2);
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
      RRect.fromRectAndRadius(const Rect.fromLTWH(16, 36, 7, 14), const Radius.circular(2)),
      Paint()..color = const Color(0xFF455A64),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(25, 36, 7, 14), const Radius.circular(2)),
      Paint()..color = const Color(0xFF37474F),
    );

    // Torso Plate Armor & Belt
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(14, 18, 20, 20), const Radius.circular(4)),
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
      RRect.fromRectAndRadius(const Rect.fromLTWH(24, 12, 9, 3), const Radius.circular(1)),
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
