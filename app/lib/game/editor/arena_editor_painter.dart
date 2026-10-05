import 'package:flutter/material.dart';

import 'editor_corner_handle.dart';
import 'motion_vector_gizmo.dart';

/// Canvas renderer responsible for drawing the visual feedback layer of the arena editor,
/// including glowing selection boundaries, corner resize handles, and kinematic gizmos.
class ArenaEditorPainter {
  const ArenaEditorPainter();

  /// Renders all active editor overlays onto [canvas].
  static void render({
    required Canvas canvas,
    required Rect? selectedRect,
    required EditorCornerHandle handle,
    required MotionVectorGizmo? activeGizmo,
    required bool isHandleHovered,
    required bool isResizing,
  }) {
    if (selectedRect == null) return;

    // Glowing selection border
    final glowPaint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawRect(selectedRect, glowPaint);

    final linePaint = Paint()
      ..color = const Color(0xFFFFD54F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(selectedRect, linePaint);

    // Corner resize handle
    handle.render(
      canvas,
      selectedRect,
      isHovered: isHandleHovered,
      isDragging: isResizing,
    );

    // Kinematic motion trajectory gizmo
    activeGizmo?.render(canvas);
  }
}
