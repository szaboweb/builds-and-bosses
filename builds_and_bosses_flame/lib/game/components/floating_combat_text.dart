import 'package:flame/components.dart';
import 'package:flutter/material.dart';

enum CombatTextStyle {
  damage,
  critical,
  heal,
  miss,
  info,
}

/// Dynamic floating text that drifts upward, scales, and fades away.
class FloatingCombatText extends TextComponent {
  final CombatTextStyle style;
  double _lifeTime = 0.0;
  static const double _maxLifeTime = 1.2;
  final Vector2 _velocity = Vector2(0, -45);

  FloatingCombatText({
    required String text,
    required Vector2 position,
    this.style = CombatTextStyle.damage,
  }) : super(
          text: text,
          position: position,
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: TextStyle(
              fontSize: style == CombatTextStyle.critical ? 20 : 16,
              fontWeight: FontWeight.bold,
              color: _getColor(style),
              shadows: const [
                Shadow(
                  color: Colors.black,
                  offset: Offset(1.5, 1.5),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        );

  static Color _getColor(CombatTextStyle style) {
    switch (style) {
      case CombatTextStyle.critical:
        return const Color(0xFFFFD700); // Gold
      case CombatTextStyle.damage:
        return const Color(0xFFFF4D4D); // Bright Red
      case CombatTextStyle.heal:
        return const Color(0xFF4EFA8A); // Bright Green
      case CombatTextStyle.miss:
        return const Color(0xFFB0BEC5); // Blue Grey
      case CombatTextStyle.info:
        return const Color(0xFF00E5FF); // Neon Cyan
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _lifeTime += dt;
    position += _velocity * dt;

    if (_lifeTime >= _maxLifeTime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = (_lifeTime / _maxLifeTime).clamp(0.0, 1.0);
    final alpha = (1.0 - progress);
    canvas.save();
    // Subtle float scale effect
    final scaleFactor = style == CombatTextStyle.critical
        ? 1.0 + 0.3 * (1.0 - progress)
        : 1.0;
    canvas.scale(scaleFactor, scaleFactor);
    canvas.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: alpha));
    super.render(canvas);
    canvas.restore();
    canvas.restore();
  }
}
