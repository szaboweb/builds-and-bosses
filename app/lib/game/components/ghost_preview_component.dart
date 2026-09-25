import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../core/actions/action_queue.dart';
import '../../core/actions/game_action.dart';
import 'player_component.dart';

/// Tactical Mode planning projection component:
/// Draws neon glowing trajectory path, waypoint markers, attack zones,
/// and a translucent ghost outline of the player at the planned destination.
class GhostPreviewComponent extends Component with HasGameReference {
  final PlayerComponent player;
  final ActionQueue queue;
  double _pulseTime = 0.0;

  GhostPreviewComponent({
    required this.player,
    required this.queue,
  });

  @override
  void update(double dt) {
    super.update(dt);
    _pulseTime += dt * 3.5;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Only render when there are actions planned
    if (queue.isEmpty) return;

    final waypoints = <Vector2>[player.position.clone()];
    Vector2 currentPos = player.position.clone();

    for (final action in queue.actions) {
      if (action is MoveAction) {
        currentPos = action.targetPosition.clone();
        waypoints.add(currentPos);
      } else if (action is DashAction) {
        currentPos = action.targetPosition.clone();
        waypoints.add(currentPos);
      }
    }

    final pulse = 0.7 + 0.3 * sin(_pulseTime);

    // 1. Draw glowing connecting path lines
    final glowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.35 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round;

    final linePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(waypoints.first.x, waypoints.first.y);
    for (int i = 1; i < waypoints.length; i++) {
      final prev = waypoints[i - 1];
      final curr = waypoints[i];
      if ((curr.y - prev.y).abs() > 20) {
        // Leaping / Jumping arc trajectory scaled by Strength jump height
        final jumpApexBonus = (player.stats.maxJumpHeight * 0.45).clamp(35.0, 75.0);
        final peakY = min(prev.y, curr.y) - jumpApexBonus;
        final midX = (prev.x + curr.x) / 2;
        path.quadraticBezierTo(midX, peakY, curr.x, curr.y);
      } else {
        path.lineTo(curr.x, curr.y);
      }
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);

    // 2. Draw waypoint nodes & action markers
    for (int i = 1; i < waypoints.length; i++) {
      final pt = waypoints[i];
      // Outer glow circle
      canvas.drawCircle(
        Offset(pt.x, pt.y),
        8 * pulse,
        Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: 0.3)
          ..style = PaintingStyle.fill,
      );
      // Inner dot
      canvas.drawCircle(
        Offset(pt.x, pt.y),
        4.5,
        Paint()..color = const Color(0xFFE0F7FA),
      );
    }

    // 3. Draw Attack zones (Slash markers)
    for (final action in queue.actions) {
      if (action is SlashAction) {
        final pos = action.targetPosition;
        // Orange/Gold attack target reticle
        final slashPaint = Paint()
          ..color = const Color(0xFFFF9100).withValues(alpha: 0.4 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        canvas.drawCircle(Offset(pos.x, pos.y), 28, slashPaint);
        canvas.drawCircle(
          Offset(pos.x, pos.y),
          28,
          Paint()
            ..color = const Color(0xFFFF9100).withValues(alpha: 0.12)
            ..style = PaintingStyle.fill,
        );

        // Crosshair ticks
        final tickPaint = Paint()
          ..color = const Color(0xFFFFD54F)
          ..strokeWidth = 2.0;
        canvas.drawLine(Offset(pos.x - 10, pos.y), Offset(pos.x + 10, pos.y), tickPaint);
        canvas.drawLine(Offset(pos.x, pos.y - 10), Offset(pos.x, pos.y + 10), tickPaint);
      }
    }

    // 4. Draw Ghost silhouette at final planned waypoint
    final finalPos = waypoints.last;
    canvas.save();
    canvas.translate(finalPos.x - player.size.x / 2, finalPos.y - player.size.y / 2);

    final ghostPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.45 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final ghostFill = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.18 * pulse)
      ..style = PaintingStyle.fill;

    // Ghost body
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(12, 12, player.size.x - 24, player.size.y - 20),
      const Radius.circular(4),
    );
    canvas.drawRRect(rect, ghostFill);
    canvas.drawRRect(rect, ghostPaint);

    // Ghost helmet circle
    canvas.drawCircle(
      Offset(player.size.x / 2, 10),
      8,
      ghostFill,
    );
    canvas.drawCircle(
      Offset(player.size.x / 2, 10),
      8,
      ghostPaint,
    );

    canvas.restore();
  }
}
