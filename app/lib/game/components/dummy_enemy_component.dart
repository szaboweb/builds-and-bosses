import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../core/combat/combat_logger.dart';
import '../../core/dnd/character_stats.dart';
import 'arena_map_component.dart';

/// Target enemy / Training Golem with health bar, physics, knockback, and hit reactions.
class DummyEnemyComponent extends PositionComponent
    with TapCallbacks, HasGameReference {
  final CharacterStats stats;
  final VoidCallback? onTapped;
  ArenaMapComponent? arena;

  Vector2 velocity = Vector2.zero();
  bool isOnGround = true;
  double _initialSpawnY = 0.0;
  bool _hasFallenOffPlatform = false;
  bool get hasFallenOffPlatform => _hasFallenOffPlatform;

  /// Kinematic displacement recorded in the last simulation frame.
  double lastDisplacementX = 0.0;
  double lastDisplacementY = 0.0;

  /// Whether characters can land and ride on top of this entity
  /// (e.g. large wolf, hellhound, or dragon).
  bool isRideable = false;

  /// Returns the top back-platform rect if [isRideable] is true.
  Rect? get rideableBackSurface {
    if (!isRideable || stats.isDead) return null;
    return Rect.fromLTWH(
      position.x - size.x / 2 + 2,
      position.y - size.y / 2,
      size.x - 4,
      12,
    );
  }

  double _hitFlashTimer = 0.0;
  double _staggerTimer = 0.0;
  static const double _hitFlashDuration = 0.25;

  double get hitFlashTimer => _hitFlashTimer;
  double get staggerTimer => _staggerTimer;

  DummyEnemyComponent({
    required Vector2 position,
    CharacterStats? stats,
    this.onTapped,
    this.arena,
    Vector2? size,
  }) : stats = stats ?? CharacterStats.trainingDummy(),
       super(
         position: position,
         size: size ?? Vector2(48, 56),
         anchor: Anchor.center,
       ) {
    _initialSpawnY = position.y;
  }

  ArenaMapComponent? get currentArena {
    if (arena != null) return arena;
    if (isMounted) {
      return game.world.children.whereType<ArenaMapComponent>().firstOrNull;
    }
    return null;
  }

  void triggerHitReaction() {
    _hitFlashTimer = _hitFlashDuration;
  }

  void triggerStagger(double value) {
    if (value <= 0) return;
    _staggerTimer = max(_staggerTimer, value / 100.0);
  }

  /// Imparts horizontal and/or vertical knockback force (px/s).
  void applyKnockback({required double forceX, double forceY = 0.0}) {
    velocity.x = forceX;
    if (forceY != 0) {
      velocity.y = forceY;
      isOnGround = false;
    }
    triggerHitReaction();
    triggerStagger(forceX.abs());
  }

  /// Pushes the dummy by a physical delta (e.g. player walking into it).
  void pushBy(double deltaX) {
    position.x += deltaX;
    lastDisplacementX = deltaX;
    lastDisplacementY = 0.0;
    _resolveCollisions(currentArena, position.y + size.y / 2);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_hitFlashTimer > 0) {
      _hitFlashTimer = max(0.0, _hitFlashTimer - dt);
    }
    if (_staggerTimer > 0) {
      _staggerTimer = max(0.0, _staggerTimer - dt);
    }
    _updatePhysics(dt);
  }

  void _updatePhysics(double dt) {
    final activeArena = currentArena;
    if (!isOnGround) {
      velocity.y += 980.0 * dt;
      velocity.y = velocity.y.clamp(-650.0, 750.0);
    } else {
      if (velocity.x != 0) {
        const friction = 360.0;
        final step = friction * dt;
        if (velocity.x.abs() <= step) {
          velocity.x = 0.0;
        } else {
          velocity.x -= velocity.x.sign * step;
        }
      }
    }

    final prevX = position.x;
    final prevY = position.y;
    final prevFeetY = position.y + size.y / 2;
    position.x += velocity.x * dt;
    position.y += velocity.y * dt;

    if (activeArena != null) {
      final minX = activeArena.leftWallX + size.x / 2;
      final maxX = activeArena.rightWallX - size.x / 2;
      position.x = position.x.clamp(minX, maxX);
    }

    _resolveCollisions(activeArena, prevFeetY);
    lastDisplacementX = position.x - prevX;
    lastDisplacementY = position.y - prevY;
  }

  void _resolveCollisions(ArenaMapComponent? activeArena, double prevFeetY) {
    if (activeArena == null) return;

    final currentFeetY = position.y + size.y / 2;
    final groundY = activeArena.groundY;

    // 1. Solid ground floor collision
    if (currentFeetY >= groundY) {
      position.y = groundY - size.y / 2;
      velocity.y = 0;
      isOnGround = true;
      if (!_hasFallenOffPlatform && position.y > _initialSpawnY + 24) {
        _hasFallenOffPlatform = true;
        CombatLogger.instance.log(
          level: LogLevel.info,
          category: 'COMBAT',
          message: '${stats.name} fell off the platform to the arena floor!',
          data: {'x': position.x, 'y': position.y},
        );
      }
      return;
    }

    // 2. Elevated platform landings
    bool landedOnPlatform = false;
    for (final plat in activeArena.platforms) {
      if (position.x >= plat.left - 6 && position.x <= plat.right + 6) {
        if (prevFeetY <= plat.top + 8 && currentFeetY >= plat.top - 2) {
          position.y = plat.top - size.y / 2;
          velocity.y = 0;
          isOnGround = true;
          landedOnPlatform = true;
          break;
        }
      }
    }

    if (!landedOnPlatform && currentFeetY < groundY) {
      isOnGround = false;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Ground contact shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y - 4),
        width: size.x - 12,
        height: 8,
      ),
      Paint()..color = Colors.black45,
    );

    final isFlashing = _hitFlashTimer > 0;
    if (_staggerTimer > 0) {
      canvas.save();
      canvas.translate(sin(_staggerTimer * 28) * 3, 0);
    }

    // Body base
    final bodyPaint = Paint()
      ..color = isFlashing
          ? Colors.white
          : (stats.isDead ? Colors.grey.shade800 : const Color(0xFF8D6E63))
      ..style = PaintingStyle.fill;

    // Golem stone body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 12, size.x - 16, size.y - 18),
      const Radius.circular(6),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // Armor outline
    final outlinePaint = Paint()
      ..color = const Color(0xFF3E2723)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(bodyRect, outlinePaint);

    // Glowing Golem eye / core
    final eyePaint = Paint()
      ..color = stats.isDead
          ? Colors.black54
          : (isFlashing ? Colors.redAccent : const Color(0xFFFF5252));
    canvas.drawCircle(Offset(size.x / 2, size.y / 2 - 4), 5, eyePaint);

    // Horns / Spikes on shoulders
    final spikePaint = Paint()..color = const Color(0xFF5D4037);
    final path = Path()
      ..moveTo(6, 16)
      ..lineTo(0, 8)
      ..lineTo(10, 12)
      ..close();
    canvas.drawPath(path, spikePaint);

    final rightPath = Path()
      ..moveTo(size.x - 6, 16)
      ..lineTo(size.x, 8)
      ..lineTo(size.x - 10, 12)
      ..close();
    canvas.drawPath(rightPath, spikePaint);

    // Health Bar overhead
    renderHealthBar(canvas);
    if (_staggerTimer > 0) canvas.restore();
  }

  void renderHealthBar(Canvas canvas) {
    const barWidth = 44.0;
    const barHeight = 6.0;
    final barLeft = (size.x - barWidth) / 2;
    const barTop = -14.0;

    // Background
    final bgPaint = Paint()..color = Colors.black87;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barLeft - 1, barTop - 1, barWidth + 2, barHeight + 2),
        const Radius.circular(3),
      ),
      bgPaint,
    );

    // Fill
    final hpRatio = (stats.currentHp / stats.maxHp).clamp(0.0, 1.0);
    final fillPaint = Paint()
      ..color = hpRatio > 0.5
          ? const Color(0xFFE53935)
          : (hpRatio > 0.25 ? Colors.orange : Colors.deepOrangeAccent);

    if (hpRatio > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barLeft, barTop, barWidth * hpRatio, barHeight),
          const Radius.circular(2),
        ),
        fillPaint,
      );
    }

    // Name & AC badge text
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${stats.name} (AC ${stats.armorClass})',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 8,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black, blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset((size.x - textPainter.width) / 2, barTop - 11),
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    onTapped?.call();
    event.handled = true;
  }
}
