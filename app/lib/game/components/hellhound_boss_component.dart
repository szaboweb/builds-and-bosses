import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/boss/boss_state_machine.dart';
import '../../core/config/boss_blueprint.dart';
import 'boss_component.dart';

/// Boss entity representing the two-headed Hellhound rendered from Blender
/// and compiled through Aseprite into an 8-frame walk animation.
///
/// Backed by data-driven [BossBlueprint] and [BossStateMachine].
class HellhoundBossComponent extends BossComponent {
  List<Sprite> _frames = const [];
  double _animationPhase = 0.0;
  bool isAssetLoaded = false;

  // Backwards compatibility convenience properties
  double get patrolDistance => blueprint.movement.patrolDistance;
  double get patrolSpeed => blueprint.movement.patrolSpeed;
  double get strideLength => blueprint.movement.strideLength;
  bool get isFacingLeft => stateMachine.isFacingLeft;
  bool get patrolDirectionRight => stateMachine.patrolDirection > 0;
  set patrolDirectionRight(bool value) {
    if (value != (stateMachine.patrolDirection > 0)) {
      stateMachine.reversePatrol();
    }
  }

  HellhoundBossComponent({
    required super.position,
    BossBlueprint? blueprint,
    BossMovementConfig? movement,
    super.onTapped,
    super.arena,
    super.stateMachine,
  }) : super(
         blueprint: _resolveBlueprint(blueprint: blueprint, movement: movement),
       );

  static BossBlueprint _resolveBlueprint({
    BossBlueprint? blueprint,
    BossMovementConfig? movement,
  }) {
    final base = blueprint ?? BossBlueprint.hellhound();
    if (movement == null) return base;
    return base.copyWith(movement: movement);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      final image = await game.images.load(blueprint.visuals.walkSheetPath);
      final frameW = blueprint.visuals.frameWidth;
      final frameH = blueprint.visuals.frameHeight;
      final frameCount = blueprint.visuals.frameCount;
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
      // Graceful fallback to procedural canvas rendering if image is unavailable in tests
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
    super.update(dt);
    if (!stats.isDead && stateMachine.canMove && isOnGround) {
      _animationPhase =
          (_animationPhase + (patrolSpeed * dt / strideLength * 8)) % 8;
    }
  }

  @override
  void render(Canvas canvas) {
    // Ground contact shadow
    renderGroundShadow(canvas, offsetY: -2, widthInset: 20);

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
