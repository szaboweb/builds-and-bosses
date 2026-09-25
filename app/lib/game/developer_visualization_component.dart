import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'components/dummy_enemy_component.dart';
import 'components/player_component.dart';
import 'developer_mode_controller.dart';

class DeveloperVisualizationComponent extends PositionComponent {
  final PlayerComponent player;
  final DummyEnemyComponent enemy;
  final DeveloperModeController mode;

  DeveloperVisualizationComponent({
    required this.player,
    required this.enemy,
    required this.mode,
  }) : super(priority: 2000);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!mode.enabled.value) return;

    _drawRange(canvas, player.position, player.stats.meleeRange, Colors.redAccent, 'MELEE');
    _drawRange(
      canvas,
      player.position,
      player.stats.config.combat.rangedNormalRange,
      Colors.amber,
      'RANGED NORMAL',
    );
    _drawRange(
      canvas,
      player.position,
      player.stats.config.combat.rangedLongRange,
      Colors.orange,
      'RANGED LONG',
    );
    _drawRange(
      canvas,
      player.position,
      player.stats.config.combat.spellRange,
      Colors.purpleAccent,
      'SPELL',
    );
    if (player.stats.darkvisionRadius > 0) {
      _drawRange(
        canvas,
        player.position,
        player.stats.darkvisionRadius,
        Colors.cyanAccent,
        'DARKVISION',
      );
    }

    final triggerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(
      Offset(player.position.x, player.position.y),
      12,
      triggerPaint,
    );
    canvas.drawLine(
      Offset(player.position.x, player.position.y - 18),
      Offset(player.position.x, player.position.y - 8),
      triggerPaint,
    );
    canvas.drawLine(
      Offset(player.position.x - 5, player.position.y - 13),
      Offset(player.position.x + 5, player.position.y - 13),
      triggerPaint,
    );

    _drawTargetTrigger(canvas, player.position, enemy.position);
  }

  void _drawRange(
    Canvas canvas,
    Vector2 center,
    double radius,
    Color color,
    String label,
  ) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(center.x, center.y), radius, paint);
  }

  void _drawTargetTrigger(Canvas canvas, Vector2 origin, Vector2 target) {
    final paint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(origin.x, origin.y),
      Offset(target.x, target.y),
      paint,
    );
    canvas.drawCircle(Offset(target.x, target.y), 10, paint);
  }
}