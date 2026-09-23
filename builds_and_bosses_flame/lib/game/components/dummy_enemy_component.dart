import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../../core/dnd/character_stats.dart';

/// Target enemy / Training Golem with health bar and hit reactions.
class DummyEnemyComponent extends PositionComponent with TapCallbacks {
  final CharacterStats stats;
  final VoidCallback? onTapped;

  double _hitFlashTimer = 0.0;
  static const double _hitFlashDuration = 0.25;

  DummyEnemyComponent({
    required Vector2 position,
    CharacterStats? stats,
    this.onTapped,
  })  : stats = stats ?? CharacterStats.trainingDummy(),
        super(
          position: position,
          size: Vector2(48, 56),
          anchor: Anchor.center,
        );

  void triggerHitReaction() {
    _hitFlashTimer = _hitFlashDuration;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_hitFlashTimer > 0) {
      _hitFlashTimer = max(0.0, _hitFlashTimer - dt);
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
    _renderHealthBar(canvas);
  }

  void _renderHealthBar(Canvas canvas) {
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
