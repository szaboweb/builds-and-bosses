import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/dnd/character_stats.dart';
import '../../core/physics/displacement_resolver.dart';
import 'arena_map_component.dart';
import 'dummy_enemy_component.dart';
import 'player_component.dart';

/// Boss entity representing the two-headed Hellhound rendered from Blender
/// and compiled through Aseprite into an 8-frame walk animation.
///
/// Features:
/// - Patrols horizontally left-to-right from spawnOriginX by [patrolDistance],
///   turns around, and patrols right-to-left symmetrically.
/// - Flips sprite horizontally when moving left.
/// - Synchronizes walk cycle steps with real ground speed.
/// - Rideable back surface allows heroes to land and jump off its body.
/// - Inherits all hit reaction, knockback, and combat coordinator contracts
///   from [DummyEnemyComponent].
class HellhoundBossComponent extends DummyEnemyComponent {
  final double patrolDistance;
  final double patrolSpeed;
  final double strideLength;

  late double spawnOriginX;
  bool isPatrolling = true;
  bool patrolDirectionRight = true;
  bool isFacingLeft = false;

  List<Sprite> _frames = const [];
  double _animationPhase = 0.0;
  bool isAssetLoaded = false;

  HellhoundBossComponent({
    required super.position,
    CharacterStats? stats,
    super.onTapped,
    super.arena,
    this.patrolDistance = 75.0,
    this.patrolSpeed = 48.0,
    this.strideLength = 48.0,
  }) : super(
         stats: stats ?? CharacterStats.hellhoundBoss(),
         size: Vector2(120, 48),
       ) {
    spawnOriginX = position.x;
    isRideable = true;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      final image = await game.images.load(
        'characters/hellhound/hellhound_walk_sheet.png',
      );
      const frameW = 160.0;
      const frameH = 64.0;
      const frameCount = 8;
      _frames = [
        for (var i = 0; i < frameCount; i++)
          Sprite(
            image,
            srcPosition: Vector2(i * frameW, 0),
            srcSize: Vector2(frameW, frameH),
          ),
      ];
      isAssetLoaded = true;
    } catch (_) {
      // Graceful fallback to canvas rendering if image is unavailable in tests
    }
  }

  @override
  Rect? get rideableBackSurface {
    if (stats.isDead) return null;
    return Rect.fromLTWH(
      position.x - size.x * 0.35,
      position.y - size.y / 2,
      size.x * 0.7,
      12,
    );
  }

  @override
  void update(double dt) {
    _updatePatrol(dt);
    super.update(dt);
  }

  void _updatePatrol(double dt) {
    if (stats.isDead || !isPatrolling) return;
    if (staggerTimer > 0 || velocity.x.abs() > 10.0 || !isOnGround) return;

    final (minBoundary, maxBoundary) = _resolvePatrolBoundaries(currentArena);

    final prevX = position.x;
    if (patrolDirectionRight) {
      position.x += patrolSpeed * dt;
      isFacingLeft = false;
      if (position.x >= maxBoundary) {
        position.x = maxBoundary;
        patrolDirectionRight = false;
      }
    } else {
      position.x -= patrolSpeed * dt;
      isFacingLeft = true;
      if (position.x <= minBoundary) {
        position.x = minBoundary;
        patrolDirectionRight = true;
      }
    }

    lastDisplacementX = position.x - prevX;
    _animationPhase =
        (_animationPhase + (patrolSpeed * dt / strideLength * 8)) % 8;

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
        targetVelocity: dir * patrolSpeed,
        isRideable: true,
        dt: dt,
      ),
    );

    if (outcome.result == PhysicalContestResult.moverWins) {
      position.x += outcome.targetDisplacement;
      position.x = position.x.clamp(minBoundary, maxBoundary);
      player.position.x = position.x + dir * combinedHalfW;
      if (position.x <= minBoundary || position.x >= maxBoundary) {
        patrolDirectionRight = !patrolDirectionRight;
      }
      return true;
    }

    if (outcome.result == PhysicalContestResult.standoff) {
      position.x -= dir * (patrolSpeed * dt);
      player.position.x = position.x + dir * combinedHalfW;
      return true;
    }

    position.x -= dir * (patrolSpeed * dt * (1.0 - outcome.moverSpeedFactor));
    return false;
  }

  /// Resolves Strength contest shove / body block between Hellhound and Player.
  /// Option B (Strength Struggle):
  /// - Passive player: pushed forward, but higher STR creates passive drag/resistance.
  /// - Active counter-push (moving towards hound):
  ///   - Hero STR < Hound STR: Hound pushes hero forward with resistance.
  ///   - Hero STR == Hound STR: Deadlock! Both halt at contact point.
  ///   - Hero STR > Hound STR: Hero overpowers the hound and shoves it backwards!
  void resolvePlayerCollision({
    required PlayerComponent player,
    ArenaMapComponent? activeArena,
    double dt = 0.016,
  }) {
    if (!_canCollideWithPlayer(player)) return;

    final combinedHalfW = (size.x + player.size.x) / 2 - 2.0;
    final dx = player.position.x - position.x;
    if (dx.abs() >= combinedHalfW) return;

    final dir = patrolDirectionRight ? 1.0 : -1.0;
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
          moverVelocity: dir * patrolSpeed,
          targetVelocity: 0.0,
          isRideable: false,
          dt: dt,
        ),
      );
      if (passiveOutcome.moverSpeedFactor < 1.0) {
        position.x -=
            dir * (patrolSpeed * dt * (1.0 - passiveOutcome.moverSpeedFactor));
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
        patrolDirectionRight = false;
      } else {
        player.position.x = max(player.position.x, pushedX);
      }
    } else {
      if (pushedX <= arenaLeft) {
        player.position.x = arenaLeft;
        position.x = arenaLeft + combinedHalfW;
        patrolDirectionRight = true;
      } else {
        player.position.x = min(player.position.x, pushedX);
      }
    }
  }

  (double, double) _resolvePatrolBoundaries(ArenaMapComponent? activeArena) {
    final minPatrolX = spawnOriginX - patrolDistance;
    final maxPatrolX = spawnOriginX + patrolDistance;
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

  @override
  void render(Canvas canvas) {
    // Ground contact shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y - 2),
        width: size.x - 20,
        height: 8,
      ),
      Paint()..color = Colors.black45,
    );

    if (staggerTimer > 0) {
      canvas.save();
      canvas.translate(sin(staggerTimer * 28) * 3, 0);
    }

    if (_frames.isNotEmpty) {
      _renderSprite(canvas);
    } else {
      _renderFallback(canvas);
    }

    renderHealthBar(canvas);

    if (staggerTimer > 0) {
      canvas.restore();
    }
  }

  void _renderSprite(Canvas canvas) {
    canvas.save();
    if (isFacingLeft) {
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }

    final frameIndex = stats.isDead
        ? 0
        : (_animationPhase.floor() % _frames.length);

    Paint? overridePaint;
    if (hitFlashTimer > 0) {
      overridePaint = Paint()
        ..colorFilter = const ColorFilter.mode(Colors.white, BlendMode.srcATop);
    } else if (stats.isDead) {
      overridePaint = Paint()
        ..colorFilter = const ColorFilter.mode(
          Colors.grey,
          BlendMode.saturation,
        );
    }

    _frames[frameIndex].render(
      canvas,
      size: size,
      overridePaint: overridePaint,
    );

    canvas.restore();
  }

  void _renderFallback(Canvas canvas) {
    final isFlashing = hitFlashTimer > 0;
    final bodyPaint = Paint()
      ..color = isFlashing
          ? Colors.white
          : (stats.isDead ? Colors.grey.shade900 : const Color(0xFF212121))
      ..style = PaintingStyle.fill;

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 14, size.x - 16, size.y - 20),
      const Radius.circular(8),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    final eyePaint = Paint()
      ..color = stats.isDead ? Colors.black54 : const Color(0xFFFF9800);
    final eyeX = isFacingLeft ? 16.0 : size.x - 16.0;
    canvas.drawCircle(Offset(eyeX, size.y / 2 - 2), 4, eyePaint);
  }
}
