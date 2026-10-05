import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/arena/arena_layout_blueprint.dart';

/// Interactive vector gizmo representing and manipulating the kinematic path
/// and turnaround distance of a moving platform in the arena editor.
class MotionVectorGizmo {
  Offset startPoint;
  Offset currentEndPoint;
  bool isDragging;
  bool isHovered;
  double handleRadius;

  MotionVectorGizmo({
    required this.startPoint,
    required this.currentEndPoint,
    this.isDragging = false,
    this.isHovered = false,
    this.handleRadius = 8.0,
  });

  /// Factory creating a gizmo initialized from a platform's current kinematics.
  factory MotionVectorGizmo.fromPlatform(PlatformBlueprint platform) {
    final origin = Offset(
      platform.x + platform.width / 2,
      platform.y + platform.height / 2,
    );
    final distance = platform.travelDistance;
    final dirX = platform.directionX;
    final end = Offset(origin.dx + (dirX * distance), origin.dy);

    return MotionVectorGizmo(startPoint: origin, currentEndPoint: end);
  }

  /// Horizontal distance between origin and current endpoint.
  double get distance => (currentEndPoint.dx - startPoint.dx).abs();

  /// Normalized horizontal direction (+1.0 or -1.0).
  double get directionX => (currentEndPoint.dx >= startPoint.dx) ? 1.0 : -1.0;

  /// Checks if [pointer] is within interactive reach of the gizmo tip handle.
  bool isTipHovering(Offset pointer, {double padding = 6.0}) {
    return (pointer - currentEndPoint).distance <= (handleRadius + padding);
  }

  /// Updates the endpoint based on [pointer] position, optionally locking
  /// to the horizontal plane and snapping the travel distance to [gridSnap].
  void updateEnd(
    Offset pointer, {
    double gridSnap = 16.0,
    bool lockHorizontal = true,
  }) {
    double deltaX = pointer.dx - startPoint.dx;
    if (gridSnap > 0) {
      deltaX = (deltaX / gridSnap).round() * gridSnap;
    }

    final double endY = lockHorizontal ? startPoint.dy : pointer.dy;
    currentEndPoint = Offset(startPoint.dx + deltaX, endY);
  }

  /// Updates the origin and synchronizes the endpoint while preserving distance and direction.
  void updateOrigin(Offset newOrigin) {
    final dist = distance;
    final dirX = directionX;
    startPoint = newOrigin;
    currentEndPoint = Offset(startPoint.dx + (dirX * dist), startPoint.dy);
  }

  /// Commits the gizmo's trajectory values directly to [platform].
  void applyToPlatform(PlatformBlueprint platform, {double speed = 90.0}) {
    final travel = distance;
    final dirX = directionX;

    platform.kinematics = PlatformKinematics(
      travelDistance: travel,
      directionX: dirX,
      directionY: 0.0,
      speed: speed,
    );

    platform.type = travel > 0
        ? PlatformType.movingStone
        : PlatformType.staticStone;
  }

  /// Renders the motion vector track line, origin anchor, arrow tip,
  /// and distance measurement onto [canvas].
  void render(Canvas canvas, {double pulse = 1.0, bool isHovered = false}) {
    final trackAlpha = (0.55 * pulse).clamp(0.2, 0.95);
    final trackColor = const Color(0xFFFF9100).withValues(alpha: trackAlpha);

    // 1. Motion track line
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(startPoint, currentEndPoint, trackPaint);

    // 2. Origin anchor (Cyan pulse dot)
    final anchorPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(startPoint, 4.5, anchorPaint);

    // 3. Arrow tip handle at current endpoint
    final active = isDragging || this.isHovered || isHovered;
    final tipFillColor = isDragging
        ? const Color(0xFFFF3D00)
        : (active ? const Color(0xFFFFD54F) : const Color(0xFFFF9100));

    final tipPaint = Paint()
      ..color = tipFillColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(currentEndPoint, handleRadius, tipPaint);

    final borderPaint = Paint()
      ..color = active ? const Color(0xFFFFFFFF) : const Color(0xFF212121)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(currentEndPoint, handleRadius, borderPaint);

    // 4. Directional chevron inside tip
    _renderChevron(canvas);
  }

  void _renderChevron(Canvas canvas) {
    final dir = directionX;
    final chevronPaint = Paint()
      ..color = const Color(0xFF212121)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final tipX = currentEndPoint.dx;
    final tipY = currentEndPoint.dy;

    final path = Path()
      ..moveTo(tipX - (dir * 2.5), tipY - 3.5)
      ..lineTo(tipX + (dir * 2.5), tipY)
      ..lineTo(tipX - (dir * 2.5), tipY + 3.5);

    canvas.drawPath(path, chevronPaint);
  }
}
