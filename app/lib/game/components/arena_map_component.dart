import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Side-view 2D Gothic Dungeon Arena Map with ground, multi-tiered platforms,
/// atmospheric background arches, and wall torches.
class ArenaMapComponent extends PositionComponent {
  final double arenaWidth;
  final double arenaHeight;

  double _torchPulse = 0.0;

  ArenaMapComponent({
    this.arenaWidth = 960.0,
    this.arenaHeight = 540.0,
  }) : super(
          position: Vector2.zero(),
          size: Vector2(arenaWidth, arenaHeight),
        );

  /// Top Y coordinate of the solid ground floor.
  double get groundY => size.y - 52.0;

  double get leftWallX => 32.0;
  double get rightWallX => size.x - 32.0;

  /// Elevated stone platforms in the arena.
  List<Rect> get platforms => [
        // Left lower platform
        Rect.fromLTWH(100, size.y - 155, 200, 20),
        // Right lower platform (ideal for boss/dummy)
        Rect.fromLTWH(size.x - 300, size.y - 155, 200, 20),
        // Center high throne platform
        Rect.fromLTWH(size.x / 2 - 130, size.y - 265, 260, 22),
        // Center upper bridge ledge
        Rect.fromLTWH(size.x / 2 - 70, size.y - 375, 140, 18),
      ];

  Rect get playableBounds => Rect.fromLTWH(
        leftWallX,
        32.0,
        rightWallX - leftWallX,
        groundY - 32.0,
      );

  @override
  void update(double dt) {
    super.update(dt);
    _torchPulse += dt * 4.0;
  }

  /// Returns the Y position of the highest surface (platform or ground) directly beneath [point].
  double getSurfaceYBelow(Vector2 point) {
    double surfaceY = groundY;
    for (final plat in platforms) {
      if (point.x >= plat.left - 12 && point.x <= plat.right + 12) {
        if (plat.top >= point.y - 8 && plat.top < surfaceY) {
          surfaceY = plat.top;
        }
      }
    }
    return surfaceY;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 1. Background dark stone dungeon wall
    final bgPaint = Paint()..color = const Color(0xFF0F111A);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), bgPaint);

    // 2. Gothic Background Pillars & Arches
    _renderBackgroundArchitecture(canvas);

    // 3. Wall Torches & Ambient Fire Glow
    _renderTorches(canvas);

    // 4. Floating Stone Platforms
    _renderPlatforms(canvas);

    // 5. Solid Ground Floor & Dungeon Base
    _renderGround(canvas);

    // 6. Side Boundary Walls
    _renderWalls(canvas);
  }

  void _renderBackgroundArchitecture(Canvas canvas) {
    final archPaint = Paint()
      ..color = const Color(0xFF161926)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final pillarFill = Paint()..color = const Color(0xFF141724);

    // Draw 5 background stone pillars
    final pillarXs = [
      size.x * 0.15,
      size.x * 0.32,
      size.x * 0.50,
      size.x * 0.68,
      size.x * 0.85
    ];

    for (final px in pillarXs) {
      // Pillar column
      canvas.drawRect(
        Rect.fromLTWH(px - 18, 30, 36, groundY - 30),
        pillarFill,
      );
      // Capital & Base trims
      canvas.drawRect(
        Rect.fromLTWH(px - 24, 30, 48, 12),
        Paint()..color = const Color(0xFF1E2235),
      );
      canvas.drawRect(
        Rect.fromLTWH(px - 24, groundY - 14, 48, 14),
        Paint()..color = const Color(0xFF1E2235),
      );
    }

    // Interconnecting gothic arches
    for (int i = 0; i < pillarXs.length - 1; i++) {
      final p1 = pillarXs[i];
      final p2 = pillarXs[i + 1];
      final mid = (p1 + p2) / 2;

      final path = Path()
        ..moveTo(p1, 100)
        ..quadraticBezierTo(mid, 35, p2, 100);
      canvas.drawPath(path, archPaint);
    }
  }

  void _renderTorches(Canvas canvas) {
    final pulse = 0.85 + 0.15 * sin(_torchPulse);
    final torchXs = [size.x * 0.22, size.x * 0.40, size.x * 0.60, size.x * 0.78];
    const torchY = 170.0;

    for (final tx in torchXs) {
      // Ambient radial warm light
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF8F00).withValues(alpha: 0.18 * pulse),
            const Color(0xFFFFB300).withValues(alpha: 0.06 * pulse),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(tx, torchY), radius: 80 * pulse));

      canvas.drawCircle(Offset(tx, torchY), 80 * pulse, glowPaint);

      // Sconce bracket
      canvas.drawRect(
        Rect.fromLTWH(tx - 4, torchY + 4, 8, 16),
        Paint()..color = const Color(0xFF37474F),
      );

      // Flame core
      canvas.drawCircle(
        Offset(tx, torchY),
        5 * pulse,
        Paint()..color = const Color(0xFFFFD54F),
      );
      canvas.drawCircle(
        Offset(tx, torchY - 2),
        3 * pulse,
        Paint()..color = Colors.white,
      );
    }
  }

  void _renderPlatforms(Canvas canvas) {
    for (final plat in platforms) {
      // Platform Drop Shadow
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          plat.translate(0, 6),
          const Radius.circular(4),
        ),
        Paint()..color = Colors.black45,
      );

      // Platform Stone Body
      final bodyRRect = RRect.fromRectAndRadius(plat, const Radius.circular(4));
      canvas.drawRRect(
        bodyRRect,
        Paint()..color = const Color(0xFF262C3D),
      );

      // Top highlighted stone ledge
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(plat.left, plat.top, plat.width, 5),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFF455A64),
      );

      // Platform border outline
      canvas.drawRRect(
        bodyRRect,
        Paint()
          ..color = const Color(0xFF1A1F2C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );

      // Subtle cyan magical rune runes on the bottom trim
      canvas.drawLine(
        Offset(plat.left + 16, plat.bottom - 2),
        Offset(plat.right - 16, plat.bottom - 2),
        Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: 0.4)
          ..strokeWidth = 1.5,
      );
    }
  }

  void _renderGround(Canvas canvas) {
    final groundRect = Rect.fromLTWH(0, groundY, size.x, size.y - groundY);

    // Deep stone ground fill
    canvas.drawRect(groundRect, Paint()..color = const Color(0xFF1B1E2B));

    // Top surface stone slab line
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, size.x, 8),
      Paint()..color = const Color(0xFF373E56),
    );

    // Border line
    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.x, groundY),
      Paint()
        ..color = const Color(0xFF546E7A)
        ..strokeWidth = 2.0,
    );

    // Checker pattern on lower earth
    final brickPaint = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.x; x += 48) {
      canvas.drawLine(Offset(x, groundY), Offset(x, size.y), brickPaint);
    }
  }

  void _renderWalls(Canvas canvas) {
    final wallPaint = Paint()..color = const Color(0xFF10131E);
    final borderPaint = Paint()
      ..color = const Color(0xFF2E344A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Left wall
    final leftRect = Rect.fromLTWH(0, 0, leftWallX, size.y);
    canvas.drawRect(leftRect, wallPaint);
    canvas.drawLine(Offset(leftWallX, 0), Offset(leftWallX, size.y), borderPaint);

    // Right wall
    final rightRect = Rect.fromLTWH(rightWallX, 0, size.x - rightWallX, size.y);
    canvas.drawRect(rightRect, wallPaint);
    canvas.drawLine(Offset(rightWallX, 0), Offset(rightWallX, size.y), borderPaint);
  }
}
