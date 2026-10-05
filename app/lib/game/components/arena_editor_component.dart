import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../editor/arena_editor_controller.dart';

/// Visual and interaction component placed into the Flame world for level editing.
///
/// Passes through all input events when disabled so gameplay is never blocked.
/// When enabled, intercepts taps and drags to move, resize, and configure platforms.
class ArenaEditorComponent extends PositionComponent
    with TapCallbacks, DragCallbacks {
  final ArenaEditorController controller;

  ArenaEditorComponent({required this.controller, required Vector2 arenaSize})
    : super(position: Vector2.zero(), size: arenaSize, priority: 999);

  @override
  bool containsLocalPoint(Vector2 point) {
    if (!controller.isEnabled) return false;
    return super.containsLocalPoint(point);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (controller.isEnabled) {
      controller.renderOverlay(canvas);
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!controller.isEnabled) return;
    controller.handlePointerDown(
      Offset(event.localPosition.x, event.localPosition.y),
    );
  }

  @override
  void onDragStart(DragStartEvent event) {
    if (!controller.isEnabled) return;
    super.onDragStart(event);
    controller.handlePointerDown(
      Offset(event.localPosition.x, event.localPosition.y),
    );
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!controller.isEnabled) return;
    controller.handlePointerMove(
      Offset(event.localEndPosition.x, event.localEndPosition.y),
    );
  }

  @override
  void onDragEnd(DragEndEvent event) {
    if (!controller.isEnabled) return;
    super.onDragEnd(event);
    controller.handlePointerUp();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    if (!controller.isEnabled) return;
    super.onDragCancel(event);
    controller.handlePointerUp();
  }
}
