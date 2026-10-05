import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Kinematic moving stone platform suspended between the lower left platform
/// and the high central throne platform.
///
/// Features D&D 2024 Strength gating: requires at least 18 STR to jump onto
/// from the lower platform and ride across the abyss.
class MovingPlatformComponent extends PositionComponent {
  final double minX;
  final double maxX;
  final double speed;
  final int requiredStrength;

  double direction;
  double lastDisplacementX = 0.0;
  double _pulseTime = 0.0;

  MovingPlatformComponent({
    required Vector2 initialPosition,
    required Vector2 size,
    required this.minX,
    required this.maxX,
    this.speed = 90.0,
    this.requiredStrength = 18,
    double initialDirection = 1.0,
  }) : direction = initialDirection,
       super(position: initialPosition, size: size, anchor: Anchor.topLeft);

  /// Returns the current bounding box of the moving platform.
  @override
  Rect toRect() => Rect.fromLTWH(position.x, position.y, size.x, size.y);

  /// Whether a character possesses sufficient Strength to land and maintain
  /// footing on this heavy floating runic platform.
  bool canSupportCharacter(int strength) => strength >= requiredStrength;

  @override
  void update(double dt) {
    super.update(dt);
    _pulseTime += dt * 3.5;

    final previousX = position.x;
    position.x += direction * speed * dt;

    if (position.x >= maxX) {
      position.x = maxX;
      direction = -1.0;
    } else if (position.x <= minX) {
      position.x = minX;
      direction = 1.0;
    }

    lastDisplacementX = position.x - previousX;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final pulse = 0.75 + 0.25 * sin(_pulseTime);
    final platRect = Rect.fromLTWH(0, 0, size.x, size.y);
    final bodyRRect = RRect.fromRectAndRadius(
      platRect,
      const Radius.circular(5),
    );

    // 1. Dynamic Drop Shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        platRect.translate(0, 8),
        const Radius.circular(6),
      ),
      Paint()..color = Colors.black54,
    );

    // 2. Underside Arcane Levitation Crystals / Energy Jets
    _renderArcaneThrusters(canvas, pulse);

    // 3. Platform Obsidian Stone Body
    canvas.drawRRect(bodyRRect, Paint()..color = const Color(0xFF22283A));

    // 4. Heavy Gold / Bronze Reinforced Border Outline
    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..color = const Color(0xFFFFB300)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // 5. Polished Stone Top Ledge
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, 5),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF546E7A),
    );

    // 6. Glowing Inscribed Runes of Might (STR 18 Sigils)
    _renderMightRunes(canvas, pulse);
  }

  void _renderArcaneThrusters(Canvas canvas, double pulse) {
    final thrusterXs = [24.0, size.x - 24.0];
    for (final tx in thrusterXs) {
      // Glow halo
      canvas.drawCircle(
        Offset(tx, size.y + 4),
        8.0 * pulse,
        Paint()
          ..color = const Color(0xFFFF8F00).withValues(alpha: 0.35 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      // Jet core
      canvas.drawCircle(
        Offset(tx, size.y + 2),
        4.0 * pulse,
        Paint()..color = const Color(0xFFFFD54F),
      );
      canvas.drawCircle(
        Offset(tx, size.y + 1),
        2.0 * pulse,
        Paint()..color = Colors.white,
      );
    }
  }

  void _renderMightRunes(Canvas canvas, double pulse) {
    final runePaint = Paint()
      ..color = const Color(0xFFFF9100).withValues(alpha: 0.65 * pulse)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final centerY = size.y / 2;

    // Glowing rune energy circuit lines across the face
    canvas.drawLine(
      Offset(36, centerY),
      Offset(size.x / 2 - 28, centerY),
      runePaint,
    );
    canvas.drawLine(
      Offset(size.x / 2 + 28, centerY),
      Offset(size.x - 36, centerY),
      runePaint,
    );

    // Central diamond sigil of Strength
    final diamondPath = Path()
      ..moveTo(size.x / 2, centerY - 6)
      ..lineTo(size.x / 2 + 10, centerY)
      ..lineTo(size.x / 2, centerY + 6)
      ..lineTo(size.x / 2 - 10, centerY)
      ..close();

    canvas.drawPath(
      diamondPath,
      Paint()
        ..color = const Color(0xFFFFB300).withValues(alpha: 0.8 * pulse)
        ..style = PaintingStyle.fill,
    );

    // Inner gold core
    canvas.drawCircle(
      Offset(size.x / 2, centerY),
      3.0,
      Paint()..color = Colors.white,
    );
  }
}
