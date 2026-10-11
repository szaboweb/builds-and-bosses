import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/dnd/character_stats.dart';
import 'base_enemy_component.dart';
export 'base_enemy_component.dart';

/// Target enemy / Training Golem with custom stone and spike graphics.
///
/// Inherits kinematics, gravity, knockback, and health tracking from [BaseEnemyComponent].
class DummyEnemyComponent extends BaseEnemyComponent {
  DummyEnemyComponent({
    required super.position,
    CharacterStats? stats,
    super.onTapped,
    super.arena,
    Vector2? size,
  }) : super(
         stats: stats ?? CharacterStats.trainingDummy(),
         size: size ?? Vector2(48, 56),
       );

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Ground contact shadow
    renderGroundShadow(canvas);

    final isFlashing = hitFlashTimer > 0;
    if (staggerTimer > 0) {
      canvas.save();
      canvas.translate(sin(staggerTimer * 28) * 3, 0);
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
    if (staggerTimer > 0) canvas.restore();
  }
}
