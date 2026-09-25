import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class LightingController extends PositionComponent {
  final PositionComponent target;
  final List<PositionComponent> visibleTargets;
  double darkvisionRadius;
  final double darknessIntensity;
  bool darknessActive = false;

  LightingController({
    required this.target,
    required this.visibleTargets,
    required Vector2 worldSize,
    required this.darkvisionRadius,
    required this.darknessIntensity,
  }) : super(size: worldSize, position: Vector2.zero(), priority: 1000);

  void setDarkness(bool active) => darknessActive = active;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!darknessActive) return;

    final visionRadius = darkvisionRadius > 0 ? darkvisionRadius : 1.0;
    final center = target.position;
    final darknessPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(center.x, center.y),
        visionRadius,
        [
          Colors.transparent,
          Colors.black.withValues(alpha: darknessIntensity * 0.55),
          Colors.black.withValues(alpha: darknessIntensity),
        ],
        const [0.0, 0.72, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), darknessPaint);

    if (darkvisionRadius <= 0) return;
    final outlinePaint = Paint()
      ..color = const Color(0xFFB2EBF2).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final visibleTarget in visibleTargets) {
      if (visibleTarget.position.distanceTo(center) <= visionRadius) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(
                visibleTarget.position.x,
                visibleTarget.position.y,
              ),
              width: visibleTarget.size.x + 10,
              height: visibleTarget.size.y + 10,
            ),
            const Radius.circular(4),
          ),
          outlinePaint,
        );
      }
    }
    canvas.drawCircle(Offset(center.x, center.y), 5, outlinePaint);
  }
}