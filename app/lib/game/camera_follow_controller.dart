import 'package:flame/components.dart';

/// Classic Metroidvania-style camera: stays still while the target is inside
/// a central dead-zone box, and scrolls only enough to keep the target at the
/// edge of that box once it steps outside. Always stays within world bounds.
class CameraFollowController {
  final CameraComponent camera;
  final PositionComponent target;
  final Vector2 worldSize;

  /// Fraction of the viewport width/height that forms the still dead-zone.
  final double deadZoneWidthFraction;
  final double deadZoneHeightFraction;

  CameraFollowController({
    required this.camera,
    required this.target,
    required this.worldSize,
    this.deadZoneWidthFraction = 0.35,
    this.deadZoneHeightFraction = 0.3,
  });

  void update() {
    final visibleRect = camera.visibleWorldRect;
    final current = camera.viewfinder.position;
    final targetPosition = target.position;

    camera.viewfinder.position = Vector2(
      _nextCenter(
        current: current.x,
        target: targetPosition.x,
        viewSize: visibleRect.width,
        deadZoneSize: visibleRect.width * deadZoneWidthFraction,
        worldSize: worldSize.x,
      ),
      _nextCenter(
        current: current.y,
        target: targetPosition.y,
        viewSize: visibleRect.height,
        deadZoneSize: visibleRect.height * deadZoneHeightFraction,
        worldSize: worldSize.y,
      ),
    );
  }

  double _nextCenter({
    required double current,
    required double target,
    required double viewSize,
    required double deadZoneSize,
    required double worldSize,
  }) {
    final halfDeadZone = deadZoneSize / 2;
    var next = current;
    if (target < current - halfDeadZone) {
      next = target + halfDeadZone;
    } else if (target > current + halfDeadZone) {
      next = target - halfDeadZone;
    }

    if (worldSize <= viewSize) return worldSize / 2;

    final halfView = viewSize / 2;
    final minimumCenter = halfView;
    final maximumCenter = worldSize - halfView;
    if (minimumCenter > maximumCenter) return worldSize / 2;
    return next.clamp(minimumCenter, maximumCenter).toDouble();
  }
}
