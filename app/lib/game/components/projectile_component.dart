import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class ProjectileComponent extends PositionComponent {
  final Vector2 targetPosition;
  final Color color;
  final double speed;

  ProjectileComponent({
    required Vector2 position,
    required this.targetPosition,
    required this.color,
    this.speed = 520,
  }) : super(position: position, size: Vector2.all(8), anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    final delta = targetPosition - position;
    final distance = delta.length;
    final step = speed * dt;
    if (distance <= step) {
      removeFromParent();
      return;
    }
    position += delta.normalized() * step;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      3,
      Paint()..color = color,
    );
  }
}
