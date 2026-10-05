import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/actions/game_action.dart';
import '../../core/dnd/character_stats.dart';
import '../../core/inventory/inventory.dart';
import 'arena_map_component.dart';
import 'dummy_enemy_component.dart';
import 'fighter_animator.dart';
import 'fighter_body_profile.dart';
import 'player_combat_controller.dart';
import 'player_locomotion_controller.dart';
import 'procedural_fighter_animator.dart';
import 'projectile_component.dart';
import '../../core/combat/combat_logger.dart';

/// Side-view Platformer Fighter Protagonist with gravity, jump physics,
/// platform landing, dynamic ground shadow, and Tactical Mode execution.
class PlayerComponent extends PositionComponent with HasGameReference {
  CharacterStats stats;
  final Rect movementBounds;

  // Realtime physics & movement — dynamically scaled by stats & GameRulesConfig.
  // Movement state, jump/flight and arena collisions are owned by PlayerLocomotionController
  // per docs/ARCHITECTURE.md ("Locomotion controller" extraction).
  final PlayerLocomotionController _locomotion = PlayerLocomotionController();
  final PlayerCombatController _combat = PlayerCombatController();

  Vector2 get velocity => _locomotion.velocity;
  set velocity(Vector2 val) => _locomotion.velocity = val;

  double get moveSpeed => stats.moveSpeed;
  double get jumpVelocity => stats.jumpVelocity;
  double get gravity => stats.config.physics.baseGravity;

  double get verticalFlightInput => _locomotion.verticalFlightInput;
  set verticalFlightInput(double val) => _locomotion.verticalFlightInput = val;

  bool get isOnGround => _locomotion.isOnGround;
  set isOnGround(bool val) => _locomotion.isOnGround = val;

  bool get isFacingLeft => _locomotion.isFacingLeft;
  set isFacingLeft(bool val) => _locomotion.isFacingLeft = val;

  // Execution state (Tactical Mode)
  bool isExecutingPlan = false;
  List<GameAction> _currentQueue = [];
  int _executingIndex = 0;
  double _actionTimer = 0.0;
  Vector2? _moveTarget;
  VoidCallback? _onPlanFinished;
  bool _hasLoggedMovingPlatformFeat = false;

  // Visuals & Animation: pose/frame selection, atlas loading and equipment
  // layers are owned by FighterAnimator (docs/ARCHITECTURE.md "Fighter
  // visual renderer" extraction).
  static final String godotFighterSheetPath =
      FighterBodyProfile.godotFighter.spriteSheetPath;

  /// Bundled character atlas currently selected for this player instance.
  String _characterSheetPath;
  String get characterSheetPath => _characterSheetPath;

  int _appearanceSelectionGeneration = 0;

  final FighterAnimator _animator = FighterAnimator();

  Sprite? get sprite => _animator.sprite;
  List<EquipmentItem> get equippedItems => _animator.equippedItems;
  List<Sprite> get equipmentSprites => _animator.equipmentSprites;

  void cancelEquipmentUpdate() => _animator.cancelEquipmentUpdate();

  Future<void> setEquipment(List<EquipmentItem> items) => _animator
      .setEquipment(List<EquipmentItem>.unmodifiable(items), game.images.load);

  /// Explicit async appearance selection operation.
  /// Validates and loads the sprite sheet before committing to the instance.
  /// Preserves the guard against selecting incompatible 32px sprites while
  /// fighter equipment is equipped.
  Future<bool> setCharacterAppearance(String path) async {
    if (path == _characterSheetPath) return true;
    if (path != godotFighterSheetPath && equippedItems.isNotEmpty) {
      CombatLogger.instance.logWarning(
        'EQUIPMENT',
        'A Godot-felszerelés a fighterhez illeszkedik. '
            'Másik sprite választása előtt vedd le a felszerelést.',
      );
      return false;
    }
    final generation = ++_appearanceSelectionGeneration;
    try {
      final success = await _animator.reload(path, game.images.load);
      if (!success) {
        return false;
      }
      if (generation != _appearanceSelectionGeneration) {
        return false;
      }
      _characterSheetPath = path;
      return true;
    } catch (e) {
      CombatLogger.instance.logWarning(
        'APPEARANCE',
        'Failed to load appearance "$path": $e',
      );
      return false;
    }
  }

  static final Paint _pixelArtPaint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;
  double _slashVfxTimer = 0.0;
  Vector2? _slashTargetPos;
  double _movementAnimationTime = 0.0;

  PlayerComponent({
    required Vector2 position,
    CharacterStats? stats,
    required this.movementBounds,
    String? characterSheetPath,
  }) : stats = stats ?? CharacterStats.fighterProtagonist(),
       _characterSheetPath = characterSheetPath ?? godotFighterSheetPath,
       super(position: position, size: Vector2(48, 52), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    await reloadCharacterSheet();
  }

  @override
  void onRemove() {
    cancelPlan();
    cancelEquipmentUpdate();
    super.onRemove();
  }

  /// Rebuilds the frame list after switching bundled character atlases.
  Future<void> reloadCharacterSheet() =>
      _animator.reload(_characterSheetPath, game.images.load);

  /// Picks idle/walk/run from the body's own speed and hands the frame
  /// selection to [FighterAnimator], which keeps feet from sliding across
  /// each body profile's own stride length.
  void _updateLocomotionFrame(double dt) {
    // velocity.x is a normalised input direction, not pixels per second.
    final speed = isExecutingPlan && _moveTarget != null
        ? moveSpeed * (_currentQueue[_executingIndex] is DashAction ? 3.8 : 2.4)
        : velocity.x.abs() * moveSpeed;
    _animator.updateLocomotionFrame(
      dt: dt,
      speed: speed,
      moveSpeed: moveSpeed,
      isOnGround: isOnGround,
    );
  }

  /// Update character stats dynamically (e.g. from Character Builder / Tervezőasztal)
  void updateStats(CharacterStats newStats) {
    stats = newStats;
    stats.currentHp = newStats.maxHp;
    stats.currentMana = newStats.maxMana;
  }

  /// Perform a jump if currently on the ground or a platform.
  bool jump() {
    if (!isExecutingPlan) {
      return _locomotion.jump(jumpVelocity: jumpVelocity);
    }
    return false;
  }

  /// Drop down through a semi-solid platform if not on the main ground floor.
  void dropDown() {
    if (!isExecutingPlan) {
      final arena = game.world.children
          .whereType<ArenaMapComponent>()
          .firstOrNull;
      _locomotion.dropDown(position: position, size: size, arena: arena);
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

  void cancelPlan() {
    isExecutingPlan = false;
    _currentQueue = [];
    _onPlanFinished = null;
    _moveTarget = null;
    _executingIndex = 0;
    _actionTimer = 0;
    _slashVfxTimer = 0;
    _slashTargetPos = null;
    _locomotion.reset();
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
      _spawn(
        ProjectileComponent(
          position: position.clone(),
          targetPosition: action.targetPosition.clone(),
          color: const Color(0xFFCE93D8),
          speed: 420,
        ),
      );
      _resolveSpell(action.targetPosition, action.knockback);
    } else if (action is RangedAction) {
      _slashTargetPos = action.targetPosition.clone();
      isFacingLeft = _slashTargetPos!.x < position.x;
      _spawn(
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

  bool canReachMelee(Vector2 targetPosition) => _combat.canReachMelee(
    playerPosition: position,
    targetPosition: targetPosition,
    stats: stats,
  );

  void _resolveSlash(Vector2 targetPos) {
    _combat.resolveSlash(
      targetPos: targetPos,
      playerPosition: position,
      stats: stats,
      enemies: game.world.children.whereType<DummyEnemyComponent>(),
      onSpawnComponent: _spawn,
    );
  }

  void _resolveSpell(Vector2 targetPos, double knockback) {
    _combat.resolveSpell(
      targetPos: targetPos,
      playerPosition: position,
      stats: stats,
      knockback: knockback,
      enemies: game.world.children.whereType<DummyEnemyComponent>(),
      onSpawnComponent: _spawn,
    );
  }

  void _resolveRanged(Vector2 targetPos) {
    _combat.resolveRanged(
      targetPos: targetPos,
      playerPosition: position,
      stats: stats,
      enemies: game.world.children.whereType<DummyEnemyComponent>(),
      onSpawnComponent: _spawn,
    );
  }

  void _resolveSecondWind() {
    _combat.resolveSecondWind(
      stats: stats,
      playerPosition: position,
      onSpawnComponent: _spawn,
    );
  }

  void _spawn(Component component) =>
      unawaited(Future<void>.sync(() => game.world.add(component)));

  @override
  void update(double dt) {
    super.update(dt);
    _movementAnimationTime += dt;

    if (_slashVfxTimer > 0) {
      _slashVfxTimer = max(0.0, _slashVfxTimer - dt);
    }

    if (isExecutingPlan) {
      _updateExecution(dt);
    } else {
      _updatePlatformerPhysics(dt);
    }
    _updateLocomotionFrame(dt);
  }

  void _updatePlatformerPhysics(double dt) {
    final arena = game.world.children
        .whereType<ArenaMapComponent>()
        .firstOrNull;
    _locomotion.characterStrength = stats.strength;
    _locomotion.updatePhysics(
      dt: dt,
      position: position,
      size: size,
      moveSpeed: moveSpeed,
      gravity: gravity,
      movementBounds: movementBounds,
      arena: arena,
    );
    if (_locomotion.isOnMovingPlatform && !_hasLoggedMovingPlatformFeat) {
      _hasLoggedMovingPlatformFeat = true;
      CombatLogger.instance.log(
        level: LogLevel.info,
        category: 'ATHLETICS',
        message:
            '${stats.name} (STR ${stats.strength}) ascended to the floating stone platform!',
      );
    }
    _combat.resolveEnemyContactPush(
      playerPosition: position,
      playerSize: size,
      stats: stats,
      playerVelocityX: velocity.x,
      dt: dt,
      enemies: game.world.children.whereType<DummyEnemyComponent>(),
    );
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
          _combat.resolveEnemyContactPush(
            playerPosition: position,
            playerSize: size,
            stats: stats,
            playerVelocityX: dir.x,
            dt: dt,
            enemies: game.world.children.whereType<DummyEnemyComponent>(),
          );
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
      final profile = _animator.profile;
      final spriteSize = Vector2.all(profile.frameSize);
      // Fixed world-root projection: do not re-anchor individual walk frames.
      final baseline = profile.rootBaselineY;
      sprite!.render(
        canvas,
        position: Vector2((size.x - spriteSize.x) / 2, size.y - baseline),
        size: spriteSize,
        overridePaint: _pixelArtPaint,
      );
      for (final equipment in equipmentSprites) {
        equipment.render(
          canvas,
          position: Vector2((size.x - 64) / 2, size.y - 54),
          size: Vector2.all(64),
          overridePaint: _pixelArtPaint,
        );
      }
    } else {
      ProceduralFighterAnimator.renderSideViewFighter(canvas);
    }
    if (!_animator.profile.usesEquipmentLayers ||
        sprite == null ||
        !_animator.hasWeapon) {
      ProceduralFighterAnimator.renderClassWeapon(
        canvas: canvas,
        classId: stats.classId,
        isFacingLeft: isFacingLeft,
        isOnGround: isOnGround,
        velocityX: velocity.x,
        movementAnimationTime: _movementAnimationTime,
        slashVfxTimer: _slashVfxTimer,
      );
    }

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
}
