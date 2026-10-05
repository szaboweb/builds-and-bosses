import 'dart:math';

import 'package:flutter/material.dart';

/// Owns fallback procedural rendering for the side-view fighter body and class weapons.
/// Extracted from PlayerComponent per docs/ARCHITECTURE.md.
class ProceduralFighterAnimator {
  ProceduralFighterAnimator._internal();

  /// Renders a side-view armored fighter model using canvas vector paths and shapes.
  static void renderSideViewFighter(Canvas canvas) {
    _renderCapeAndGreaves(canvas);
    _renderArmorAndWeapons(canvas);
  }

  static void _renderCapeAndGreaves(Canvas canvas) {
    // Flowing Cape (Back)
    final capePath = Path()
      ..moveTo(12, 18)
      ..lineTo(2, 42)
      ..lineTo(16, 44)
      ..lineTo(20, 22)
      ..close();
    canvas.drawPath(capePath, Paint()..color = const Color(0xFFB71C1C));

    // Plate Leg Greaves
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(16, 36, 7, 14),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF455A64),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(25, 36, 7, 14),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF37474F),
    );
  }

  static void _renderArmorAndWeapons(Canvas canvas) {
    // Torso Plate Armor & Belt
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(14, 18, 20, 20),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF78909C),
    );
    canvas.drawRect(
      const Rect.fromLTWH(14, 34, 20, 4),
      Paint()..color = const Color(0xFFFFD54F),
    );

    // Helmet & Visor
    canvas.drawCircle(
      const Offset(24, 14),
      9,
      Paint()..color = const Color(0xFF546E7A),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(24, 12, 9, 3),
        const Radius.circular(1),
      ),
      Paint()..color = const Color(0xFFFFD54F),
    );

    // Left Arm with Heavy Shield
    canvas.drawOval(
      const Rect.fromLTWH(10, 19, 10, 18),
      Paint()..color = const Color(0xFF1E88E5),
    );
    canvas.drawOval(
      const Rect.fromLTWH(12, 21, 6, 14),
      Paint()
        ..color = const Color(0xFFFFD54F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Right Arm with Broadsword & Crossguard
    final bladePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(32, 26), const Offset(44, 8), bladePaint);
    canvas.drawLine(
      const Offset(28, 24),
      const Offset(35, 29),
      Paint()
        ..color = const Color(0xFFFFD54F)
        ..strokeWidth = 2.5,
    );
  }

  /// Renders a dynamic class-themed weapon matching character class and swing state.
  static void renderClassWeapon({
    required Canvas canvas,
    required String classId,
    required bool isFacingLeft,
    required bool isOnGround,
    required double velocityX,
    required double movementAnimationTime,
    required double slashVfxTimer,
  }) {
    final isAttacking = slashVfxTimer > 0;
    final attackProgress = isAttacking ? 1.0 - (slashVfxTimer / 0.35) : 0.0;
    final walkSwing = isOnGround && velocityX != 0
        ? sin(movementAnimationTime * 12.0) * 0.18
        : 0.0;
    final swing = isAttacking ? sin(attackProgress * pi) * 1.15 : walkSwing;
    const hand = Offset(31, 27);
    final direction = isFacingLeft ? -1.0 : 1.0;

    canvas.save();
    canvas.translate(hand.dx, hand.dy);
    canvas.rotate(direction * swing);
    canvas.translate(-hand.dx, -hand.dy);

    canvas.drawLine(
      Offset(hand.dx - direction * 2, hand.dy - 1),
      Offset(hand.dx + direction * 4, hand.dy + 2),
      Paint()..color = const Color(0xFFD49A62),
    );

    switch (classId) {
      case 'rogue':
        _renderRogueWeapon(canvas, hand, direction);
        break;
      case 'cleric':
        _renderClericWeapon(canvas, hand, direction);
        break;
      case 'fighter':
      default:
        _renderFighterWeapon(canvas, hand, direction);
        break;
    }
    canvas.restore();
  }

  static void _renderRogueWeapon(Canvas canvas, Offset hand, double direction) {
    final paint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      hand,
      Offset(hand.dx + direction * 13, hand.dy - 10),
      paint,
    );
    canvas.drawLine(
      Offset(hand.dx + direction * 2, hand.dy + 1),
      Offset(hand.dx + direction * 5, hand.dy + 4),
      Paint()
        ..color = const Color(0xFFB8784F)
        ..strokeWidth = 2,
    );
  }

  static void _renderClericWeapon(
    Canvas canvas,
    Offset hand,
    double direction,
  ) {
    final paint = Paint()
      ..color = const Color(0xFFB8784F)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(hand, Offset(hand.dx + direction * 2, hand.dy - 22), paint);
    final gold = Paint()
      ..color = const Color(0xFFFFD54F)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(hand.dx + direction * 2, hand.dy - 24),
      Offset(hand.dx + direction * 2, hand.dy - 19),
      gold,
    );
    canvas.drawLine(
      Offset(hand.dx - direction * 1, hand.dy - 22),
      Offset(hand.dx + direction * 5, hand.dy - 22),
      gold,
    );
  }

  static void _renderFighterWeapon(
    Canvas canvas,
    Offset hand,
    double direction,
  ) {
    final paint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      hand,
      Offset(hand.dx + direction * 17, hand.dy - 21),
      paint,
    );
    canvas.drawLine(
      Offset(hand.dx + direction * 1, hand.dy - 1),
      Offset(hand.dx + direction * 7, hand.dy + 5),
      Paint()
        ..color = const Color(0xFFFFD54F)
        ..strokeWidth = 2.5,
    );
  }
}
