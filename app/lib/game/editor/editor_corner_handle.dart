import 'dart:math';

import 'package:flutter/material.dart';

/// Interactive corner handle positioned at the bottom-right of a selected platform.
///
/// Supports hit-testing, proximity hover detection, rendering with visual feedback,
/// and calculating diagonal resize constraints with optional grid snapping.
class EditorCornerHandle {
  static const double handleSize = 14.0;
  static const double minWidth = 64.0;
  static const double minHeight = 16.0;

  const EditorCornerHandle();

  /// Calculates the bounding rectangle of the handle for a given target rect.
  Rect getHandleRect(Rect target) {
    return Rect.fromCenter(
      center: Offset(target.right, target.bottom),
      width: handleSize,
      height: handleSize,
    );
  }

  /// Determines whether [mousePos] is hovering within or near the handle hitbox.
  bool isHovering(Rect target, Offset mousePos, {double padding = 4.0}) {
    return getHandleRect(target).inflate(padding).contains(mousePos);
  }

  /// Calculates a resized [Rect] based on the current mouse position,
  /// clamped by minimum platform dimensions and aligned to [gridSnap].
  Rect applyResize({
    required Rect target,
    required Offset currentMousePos,
    double gridSnap = 16.0,
    double minWidth = minWidth,
    double minHeight = minHeight,
  }) {
    double newWidth = max(minWidth, currentMousePos.dx - target.left);
    double newHeight = max(minHeight, currentMousePos.dy - target.top);

    if (gridSnap > 0) {
      newWidth = max(minWidth, (newWidth / gridSnap).round() * gridSnap);
      newHeight = max(minHeight, (newHeight / gridSnap).round() * gridSnap);
    }

    return Rect.fromLTWH(target.left, target.top, newWidth, newHeight);
  }

  /// Renders the handle onto [canvas] with distinct visual states for idle,
  /// hovered, and dragging interactions.
  void render(
    Canvas canvas,
    Rect target, {
    bool isHovered = false,
    bool isDragging = false,
  }) {
    final handleRect = getHandleRect(target);
    final rrect = RRect.fromRectAndRadius(
      handleRect,
      const Radius.circular(2.5),
    );

    final fillColor = isDragging
        ? const Color(0xFFFF9100)
        : (isHovered ? const Color(0xFFFFE082) : const Color(0xFFFFCA28));

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isHovered || isDragging
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF212121)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(rrect, fillPaint);
    canvas.drawRRect(rrect, borderPaint);

    // Diagonal grip icon inside the handle
    final gripPaint = Paint()
      ..color = isDragging
          ? const Color(0xFF3E2723)
          : (isHovered ? const Color(0xFF424242) : const Color(0xFF616161))
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final center = handleRect.center;
    canvas.drawLine(
      Offset(center.dx - 3, center.dy + 3),
      Offset(center.dx + 3, center.dy - 3),
      gripPaint,
    );
  }
}
