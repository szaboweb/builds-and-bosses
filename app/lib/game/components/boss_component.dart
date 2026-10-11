import 'dart:math';

import 'package:flame/components.dart';

import '../../core/boss/boss_state_machine.dart';
import '../../core/config/boss_blueprint.dart';
import '../../core/physics/displacement_resolver.dart';
import 'arena_map_component.dart';
import 'base_enemy_component.dart';
import 'player_component.dart';

/// Base class for all 12 major Boss entities in Builds & Bosses.
///
/// Encapsulates:
/// - Data-driven [BossBlueprint] (stats, size, patrol config, visual meta)
/// - Finite [BossStateMachine] governing AI states (patrol, windup, attack, stagger, dead)
/// - Platform and arena boundary detection
/// - Universal deterministic physical contest resolution with the hero
abstract class BossComponent extends BaseEnemyComponent {
  final BossBlueprint blueprint;
  final BossStateMachine stateMachine;

  late double spawnOriginX;

  BossComponent({
    required super.position,
    required this.blueprint,
    super.onTapped,
    super.arena,
    BossStateMachine? stateMachine,
  }) : stateMachine = stateMachine ?? BossStateMachine(),
       super(
         stats: blueprint.stats,
         size: Vector2(blueprint.width, blueprint.height),
       ) {
    spawnOriginX = position.x;
    isRideable = blueprint.isRideable;
  }

  @override
  void update(double dt) {
    stateMachine.update(dt);
    if (stats.isDead && stateMachine.state != BossState.dead) {
      stateMachine.triggerDeath();
    }
    _updatePatrol(dt);
    super.update(dt);
  }

  void _updatePatrol(double dt) {
    if (stats.isDead || !stateMachine.canMove) return;
    if (staggerTimer > 0 || velocity.x.abs() > 10.0 || !isOnGround) return;

    final (minBoundary, maxBoundary) = _resolvePatrolBoundaries(currentArena);
    final prevX = position.x;
    final dir = stateMachine.patrolDirection;
    final speed = blueprint.movement.patrolSpeed;

    position.x += dir * speed * dt;

    if (dir > 0 && position.x >= maxBoundary) {
      position.x = maxBoundary;
      stateMachine.reversePatrol();
    } else if (dir < 0 && position.x <= minBoundary) {
      position.x = minBoundary;
      stateMachine.reversePatrol();
    }

    lastDisplacementX = position.x - prevX;

    final player = isMounted
        ? game.world.children.whereType<PlayerComponent>().firstOrNull
        : null;
    if (player != null) {
      resolvePlayerCollision(player: player, activeArena: currentArena, dt: dt);
    }
  }

  bool _canCollideWithPlayer(PlayerComponent player) {
    if (player.stats.isDead || player.isGaseous) return false;
    final houndTop = position.y - size.y / 2;
    final houndBottom = position.y + size.y / 2;
    final playerFeet = player.position.y + player.size.y / 2;
    final playerHead = player.position.y - player.size.y / 2;
    if (playerFeet <= houndTop + 6) return false;
    return playerFeet >= houndTop && playerHead <= houndBottom;
  }

  bool _resolveCounterPush({
    required PlayerComponent player,
    required double dir,
    required double combinedHalfW,
    required double minBoundary,
    required double maxBoundary,
    required double dt,
  }) {
    const resolver = PhysicalContestResolver();
    final outcome = resolver.resolve(
      PhysicalContestRequest(
        moverStr: player.stats.strength,
        targetStr: stats.strength,
        moverVelocity: player.velocity.x * player.moveSpeed,
        targetVelocity: dir * blueprint.movement.patrolSpeed,
        isRideable: isRideable,
        dt: dt,
      ),
    );

    if (outcome.result == PhysicalContestResult.moverWins) {
      position.x += outcome.targetDisplacement;
      position.x = position.x.clamp(minBoundary, maxBoundary);
      player.position.x = position.x + dir * combinedHalfW;
      if (position.x <= minBoundary || position.x >= maxBoundary) {
        stateMachine.reversePatrol();
      }
      return true;
    }

    if (outcome.result == PhysicalContestResult.standoff) {
      position.x -= dir * (blueprint.movement.patrolSpeed * dt);
      player.position.x = position.x + dir * combinedHalfW;
      return true;
    }

    position.x -=
        dir *
        (blueprint.movement.patrolSpeed *
            dt *
            (1.0 - outcome.moverSpeedFactor));
    return false;
  }

  /// Resolves Strength contest shove / body block between Boss and Player.
  void resolvePlayerCollision({
    required PlayerComponent player,
    ArenaMapComponent? activeArena,
    double dt = 0.016,
  }) {
    if (!_canCollideWithPlayer(player)) return;

    final combinedHalfW = (size.x + player.size.x) / 2 - 2.0;
    final dx = player.position.x - position.x;
    if (dx.abs() >= combinedHalfW) return;

    final dir = stateMachine.patrolDirection;
    if (dx * dir < -size.x * 0.25) return;

    final (minBoundary, maxBoundary) = _resolvePatrolBoundaries(activeArena);
    final isCounterPushing = player.velocity.x * dir < -0.1;

    if (isCounterPushing) {
      final handled = _resolveCounterPush(
        player: player,
        dir: dir,
        combinedHalfW: combinedHalfW,
        minBoundary: minBoundary,
        maxBoundary: maxBoundary,
        dt: dt,
      );
      if (handled) return;
    } else if (player.velocity.x.abs() <= 0.1) {
      const resolver = PhysicalContestResolver();
      final passiveOutcome = resolver.resolve(
        PhysicalContestRequest(
          moverStr: stats.strength,
          targetStr: player.stats.strength,
          moverVelocity: dir * blueprint.movement.patrolSpeed,
          targetVelocity: 0.0,
          isRideable: false,
          dt: dt,
        ),
      );
      if (passiveOutcome.moverSpeedFactor < 1.0) {
        position.x -=
            dir *
            (blueprint.movement.patrolSpeed *
                dt *
                (1.0 - passiveOutcome.moverSpeedFactor));
      }
    }

    final arenaLeft = (activeArena?.leftWallX ?? 0) + player.size.x / 2;
    final arenaRight = (activeArena?.rightWallX ?? 9999) - player.size.x / 2;
    _clampAndPushPlayer(player, dir, combinedHalfW, arenaLeft, arenaRight);
  }

  void _clampAndPushPlayer(
    PlayerComponent player,
    double dir,
    double combinedHalfW,
    double arenaLeft,
    double arenaRight,
  ) {
    final pushedX = position.x + dir * combinedHalfW;
    if (dir > 0) {
      if (pushedX >= arenaRight) {
        player.position.x = arenaRight;
        position.x = arenaRight - combinedHalfW;
        stateMachine.reversePatrol();
      } else {
        player.position.x = max(player.position.x, pushedX);
      }
    } else {
      if (pushedX <= arenaLeft) {
        player.position.x = arenaLeft;
        position.x = arenaLeft + combinedHalfW;
        stateMachine.reversePatrol();
      } else {
        player.position.x = min(player.position.x, pushedX);
      }
    }
  }

  (double, double) _resolvePatrolBoundaries(ArenaMapComponent? activeArena) {
    final minPatrolX = spawnOriginX - blueprint.movement.patrolDistance;
    final maxPatrolX = spawnOriginX + blueprint.movement.patrolDistance;
    if (activeArena == null) return (minPatrolX, maxPatrolX);

    double minBoundary = minPatrolX;
    double maxBoundary = maxPatrolX;
    final currentFeetY = position.y + size.y / 2;

    for (final plat in activeArena.platforms) {
      if (position.x >= plat.left - 10 && position.x <= plat.right + 10) {
        if ((currentFeetY - plat.top).abs() <= 6) {
          minBoundary = max(minBoundary, plat.left + size.x * 0.35);
          maxBoundary = min(maxBoundary, plat.right - size.x * 0.35);
          break;
        }
      }
    }

    minBoundary = max(minBoundary, activeArena.leftWallX + size.x / 2);
    maxBoundary = min(maxBoundary, activeArena.rightWallX - size.x / 2);
    return (minBoundary, maxBoundary);
  }
}
