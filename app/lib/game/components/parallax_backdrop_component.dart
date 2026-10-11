import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 3-Layer Procedural Gothic Dungeon Parallax Backdrop.
///
/// Layers:
/// - Layer 1 (Far, 0.15x): Midnight gothic sky, moon, and distant spire silhouettes.
/// - Layer 2 (Mid, 0.40x): Ancient ruined catacomb arches and stone window traceries.
/// - Layer 3 (Near, 0.75x): Imposing stone dungeon pillars and atmospheric drifting fog.
class ParallaxBackdropComponent extends PositionComponent
    with HasGameReference {
  final double arenaWidth;
  final double arenaHeight;

  double _ambientTimer = 0.0;

  ParallaxBackdropComponent({
    required this.arenaWidth,
    required this.arenaHeight,
  }) : super(
         position: Vector2.zero(),
         size: Vector2(arenaWidth, arenaHeight),
         priority: -100,
       );

  @override
  void update(double dt) {
    super.update(dt);
    _ambientTimer += dt * 0.4;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final cameraX = isMounted ? game.camera.viewfinder.position.x : 0.0;

    // 1. Far Parallax (0.15x scroll factor)
    _renderFarLayer(canvas, cameraX);

    // 2. Mid Parallax (0.40x scroll factor)
    _renderMidLayer(canvas, cameraX);

    // 3. Near Parallax (0.75x scroll factor)
    _renderNearLayer(canvas, cameraX);
  }

  /// Layer 1: Midnight sky gradient and distant cathedral spires.
  void _renderFarLayer(Canvas canvas, double cameraX) {
    final scrollOffset = cameraX * (1.0 - 0.15);

    // Deep midnight sky background
    final skyPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.y),
        [
          const Color(0xFF06080F),
          const Color(0xFF0D101C),
          const Color(0xFF141726),
        ],
        const [0.0, 0.6, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), skyPaint);

    // Distant pale moon
    canvas.save();
    canvas.translate(scrollOffset, 0);

    final moonPaint = Paint()
      ..color = const Color(0xFF8C95B2).withValues(alpha: 0.18);
    final moonGlow = Paint()
      ..color = const Color(0xFF6B7596).withValues(alpha: 0.08);
    const moonCenter = Offset(240, 110);
    canvas.drawCircle(moonCenter, 46, moonGlow);
    canvas.drawCircle(moonCenter, 32, moonPaint);

    // Distant mountain & cathedral spires silhouette
    final spirePaint = Paint()..color = const Color(0xFF0A0C16);
    final path = Path()..moveTo(-100, size.y);

    const stepWidth = 140.0;
    final totalSteps = ((size.x + 300) / stepWidth).ceil();

    for (var i = 0; i < totalSteps; i++) {
      final x = -100 + i * stepWidth;
      final peakHeight = 120.0 + sin(i * 1.7) * 45.0;
      final peakY = size.y - peakHeight - 60;

      // Steep triangular spire
      path.lineTo(x + stepWidth * 0.45, peakY);
      path.lineTo(x + stepWidth * 0.55, peakY);
      path.lineTo(x + stepWidth, size.y);
    }
    path.close();
    canvas.drawPath(path, spirePaint);

    canvas.restore();
  }

  /// Layer 2: Ancient ruined catacomb arches and window traceries.
  void _renderMidLayer(Canvas canvas, double cameraX) {
    final scrollOffset = cameraX * (1.0 - 0.40);

    canvas.save();
    canvas.translate(scrollOffset, 0);

    final archPaint = Paint()
      ..color = const Color(0xFF131623)
      ..style = PaintingStyle.fill;
    final trimPaint = Paint()
      ..color = const Color(0xFF1C2033)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    const span = 200.0;
    final archCount = ((size.x + 400) / span).ceil();

    for (var i = -1; i < archCount; i++) {
      final left = i * span;
      final right = left + span;
      final midX = (left + right) / 2;
      const archTopY = 140.0;
      final archBottomY = size.y - 65.0;

      final archPath = Path()
        ..moveTo(left + 22, archBottomY)
        ..lineTo(left + 22, archTopY + 50)
        ..quadraticBezierTo(midX, archTopY - 20, right - 22, archTopY + 50)
        ..lineTo(right - 22, archBottomY)
        ..close();

      canvas.drawPath(archPath, archPaint);
      canvas.drawPath(archPath, trimPaint);

      // Window traceries / cross slits
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(midX, archTopY + 45),
          width: 6,
          height: 38,
        ),
        Paint()..color = const Color(0xFF1D2235),
      );
    }

    canvas.restore();
  }

  /// Layer 3: Imposing stone dungeon pillars and atmospheric drifting fog.
  void _renderNearLayer(Canvas canvas, double cameraX) {
    final scrollOffset = cameraX * (1.0 - 0.75);

    canvas.save();
    canvas.translate(scrollOffset, 0);

    final pillarFill = Paint()..color = const Color(0xFF171A29);
    final capitalPaint = Paint()..color = const Color(0xFF22273D);

    const pillarSpacing = 280.0;
    final pillarCount = ((size.x + 500) / pillarSpacing).ceil();

    for (var i = -1; i < pillarCount; i++) {
      final px = i * pillarSpacing + 40.0;
      const pillarW = 44.0;
      const topY = 40.0;
      final bottomY = size.y - 52.0;

      // Shaft
      canvas.drawRect(
        Rect.fromLTWH(px - pillarW / 2, topY, pillarW, bottomY - topY),
        pillarFill,
      );

      // Capital & Base
      canvas.drawRect(
        Rect.fromLTWH(px - pillarW / 2 - 8, topY, pillarW + 16, 16),
        capitalPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(px - pillarW / 2 - 8, bottomY - 18, pillarW + 16, 18),
        capitalPaint,
      );
    }

    // Drifting ground fog layer
    final fogShift = sin(_ambientTimer) * 35.0;
    final fogPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, size.y - 140),
        Offset(0, size.y - 40),
        [
          Colors.transparent,
          const Color(0xFF1E2338).withValues(alpha: 0.25),
          const Color(0xFF0F121E).withValues(alpha: 0.45),
        ],
        const [0.0, 0.5, 1.0],
      );

    canvas.drawRect(
      Rect.fromLTWH(-100 + fogShift, size.y - 140, size.x + 400, 100),
      fogPaint,
    );

    canvas.restore();
  }
}
