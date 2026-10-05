import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/arena/arena_layout_blueprint.dart';
import '../../core/utils/unique_id.dart';
import 'arena_editor_painter.dart';
import 'editor_corner_handle.dart';
import 'motion_vector_gizmo.dart';

/// Active interaction mode during drag gestures in the arena editor.
enum EditorDragMode { none, move, resize, dragVector }

/// Headless controller coordinating arena level editing interactions,
/// including platform selection, dragging to move, corner handle resizing,
/// motion trajectory gizmo dragging, grid snapping, and visual overlay rendering.
class ArenaEditorController extends ChangeNotifier {
  ArenaLayoutBlueprint blueprint;
  final EditorCornerHandle handle;

  bool _isEnabled = false;
  bool snapToGrid = true;
  double gridSize = 16.0;

  String? _selectedPlatformId;
  String? _hoveredPlatformId;
  bool _isHandleHovered = false;
  EditorDragMode _dragMode = EditorDragMode.none;
  MotionVectorGizmo? _activeGizmo;

  Offset? _dragStartPointer;
  Rect? _initialPlatformRect;

  ArenaEditorController({
    required this.blueprint,
    this.handle = const EditorCornerHandle(),
    bool enabled = false,
  }) : _isEnabled = enabled;

  bool get isEnabled => _isEnabled;
  set isEnabled(bool value) {
    if (_isEnabled == value) return;
    _isEnabled = value;
    if (!_isEnabled) {
      clearSelection();
    } else {
      notifyListeners();
    }
  }

  String? get selectedPlatformId => _selectedPlatformId;
  String? get hoveredPlatformId => _hoveredPlatformId;
  bool get isHandleHovered => _isHandleHovered;
  MotionVectorGizmo? get activeGizmo => _activeGizmo;
  EditorDragMode get dragMode => _dragMode;
  bool get isDragging => _dragMode != EditorDragMode.none;
  int get platformCount => blueprint.platforms.length;

  PlatformBlueprint? get selectedPlatform {
    if (_selectedPlatformId == null) return null;
    for (final p in blueprint.platforms) {
      if (p.id == _selectedPlatformId) return p;
    }
    return null;
  }

  Rect? get selectedPlatformRect {
    final p = selectedPlatform;
    return p != null ? Rect.fromLTWH(p.x, p.y, p.width, p.height) : null;
  }

  Rect? get selectedHandleRect {
    final r = selectedPlatformRect;
    return r != null ? handle.getHandleRect(r) : null;
  }

  /// Selects a platform by [id], or clears selection if [id] is null.
  void selectPlatform(String? id) {
    if (_selectedPlatformId == id) return;
    _selectedPlatformId = id;
    _dragMode = EditorDragMode.none;
    _dragStartPointer = null;
    _initialPlatformRect = null;
    _syncActiveGizmo();
    notifyListeners();
  }

  void _syncActiveGizmo() {
    final plat = selectedPlatform;
    if (plat != null && plat.isMoving) {
      _activeGizmo = MotionVectorGizmo.fromPlatform(plat);
    } else {
      _activeGizmo = null;
    }
  }

  /// Deselects the currently active platform.
  void clearSelection() => selectPlatform(null);

  /// Finds the top-most platform intersecting [position], if any.
  PlatformBlueprint? platformAt(Offset position) {
    for (final p in blueprint.platforms.reversed) {
      final rect = Rect.fromLTWH(p.x, p.y, p.width, p.height);
      if (rect.contains(position)) return p;
    }
    return null;
  }

  /// Handles pointer press at [worldPosition].
  ///
  /// Returns `true` if an editor element (handle or platform) consumed the tap.
  bool handlePointerDown(Offset worldPosition) {
    if (!_isEnabled) return false;

    if (_activeGizmo != null && _activeGizmo!.isTipHovering(worldPosition)) {
      _dragMode = EditorDragMode.dragVector;
      _activeGizmo!.isDragging = true;
      _dragStartPointer = worldPosition;
      notifyListeners();
      return true;
    }

    final currentRect = selectedPlatformRect;
    if (currentRect != null && handle.isHovering(currentRect, worldPosition)) {
      _dragMode = EditorDragMode.resize;
      _dragStartPointer = worldPosition;
      _initialPlatformRect = currentRect;
      notifyListeners();
      return true;
    }

    final hit = platformAt(worldPosition);
    if (hit != null) {
      _selectedPlatformId = hit.id;
      _dragMode = EditorDragMode.move;
      _dragStartPointer = worldPosition;
      _initialPlatformRect = Rect.fromLTWH(hit.x, hit.y, hit.width, hit.height);
      _syncActiveGizmo();
      notifyListeners();
      return true;
    }

    if (_selectedPlatformId != null) clearSelection();
    return false;
  }

  /// Handles pointer movement at [worldPosition].
  ///
  /// Returns `true` if an active drag operation updated platform geometry.
  bool handlePointerMove(Offset worldPosition) {
    if (!_isEnabled) return false;

    if (_dragMode == EditorDragMode.dragVector) {
      return _applyVectorDrag(worldPosition);
    }

    if (_dragMode == EditorDragMode.resize) {
      return _applyResizeDrag(worldPosition);
    }

    if (_dragMode == EditorDragMode.move) {
      return _applyMoveDrag(worldPosition);
    }

    final currentRect = selectedPlatformRect;
    _isHandleHovered =
        currentRect != null && handle.isHovering(currentRect, worldPosition);
    if (_activeGizmo != null) {
      _activeGizmo!.isHovered = _activeGizmo!.isTipHovering(worldPosition);
    }
    _hoveredPlatformId = platformAt(worldPosition)?.id;
    notifyListeners();
    return false;
  }

  /// Concludes any active drag operation.
  void handlePointerUp() {
    if (_dragMode == EditorDragMode.none) return;
    _activeGizmo?.isDragging = false;
    _dragMode = EditorDragMode.none;
    _dragStartPointer = null;
    _initialPlatformRect = null;
    notifyListeners();
  }

  bool _applyVectorDrag(Offset worldPosition) {
    final gizmo = _activeGizmo;
    final platform = selectedPlatform;
    if (gizmo == null || platform == null) return false;

    gizmo.updateEnd(worldPosition, gridSnap: snapToGrid ? gridSize : 0.0);
    gizmo.applyToPlatform(platform);
    notifyListeners();
    return true;
  }

  bool _applyResizeDrag(Offset worldPosition) {
    final platform = selectedPlatform;
    final initial = _initialPlatformRect;
    if (platform == null || initial == null) return false;

    final resized = handle.applyResize(
      target: initial,
      currentMousePos: worldPosition,
      gridSnap: snapToGrid ? gridSize : 0.0,
    );

    platform.width = resized.width;
    platform.height = resized.height;
    notifyListeners();
    return true;
  }

  bool _applyMoveDrag(Offset worldPosition) {
    final platform = selectedPlatform;
    final initial = _initialPlatformRect;
    final start = _dragStartPointer;
    if (platform == null || initial == null || start == null) return false;

    final delta = worldPosition - start;
    double newX = initial.left + delta.dx;
    double newY = initial.top + delta.dy;

    if (snapToGrid && gridSize > 0) {
      newX = (newX / gridSize).round() * gridSize;
      newY = (newY / gridSize).round() * gridSize;
    }

    final maxX = max(0.0, blueprint.arenaWidth - platform.width);
    final maxY = max(0.0, blueprint.arenaHeight - platform.height);
    platform.x = newX.clamp(0.0, maxX);
    platform.y = newY.clamp(0.0, maxY);

    if (_activeGizmo != null) {
      _activeGizmo!.updateOrigin(
        Offset(
          platform.x + platform.width / 2,
          platform.y + platform.height / 2,
        ),
      );
    }

    notifyListeners();
    return true;
  }

  /// Adds a new platform to the arena layout and selects it.
  PlatformBlueprint addPlatform({
    required PlatformType type,
    required double x,
    required double y,
    double width = 160.0,
    double height = 20.0,
    PlatformKinematics? kinematics,
  }) {
    final id = UniqueId.next('plat');
    final platform = PlatformBlueprint(
      id: id,
      type: type,
      x: x,
      y: y,
      width: width,
      height: height,
      kinematics: kinematics,
    );
    blueprint.platforms.add(platform);
    selectPlatform(id);
    return platform;
  }

  /// Removes the currently selected platform from the arena layout.
  bool removeSelectedPlatform() {
    final id = _selectedPlatformId;
    if (id == null) return false;
    blueprint.platforms.removeWhere((p) => p.id == id);
    clearSelection();
    return true;
  }

  /// Clones the currently selected platform with a displacement offset.
  PlatformBlueprint? duplicateSelectedPlatform({
    double offsetX = 32.0,
    double offsetY = 32.0,
  }) {
    final source = selectedPlatform;
    if (source == null) return null;

    final k = source.kinematics;
    final duplicate = PlatformBlueprint(
      id: UniqueId.next('plat'),
      type: source.type,
      x: source.x + offsetX,
      y: source.y + offsetY,
      width: source.width,
      height: source.height,
      kinematics: k != null
          ? PlatformKinematics(
              travelDistance: k.travelDistance,
              directionX: k.directionX,
              directionY: k.directionY,
              speed: k.speed,
            )
          : null,
    );

    blueprint.platforms.add(duplicate);
    selectPlatform(duplicate.id);
    return duplicate;
  }

  /// Toggles between static stone and kinematic moving platform on the selected platform.
  void toggleSelectedPlatformMotion({double defaultDistance = 160.0}) {
    final platform = selectedPlatform;
    if (platform == null) return;

    final willMove = !platform.isMoving;
    platform.type = willMove
        ? PlatformType.movingStone
        : PlatformType.staticStone;
    platform.kinematics = willMove
        ? PlatformKinematics(
            travelDistance: defaultDistance,
            directionX: 1.0,
            speed: 90.0,
          )
        : null;
    _syncActiveGizmo();
    notifyListeners();
  }

  /// Renders editor bounding boxes and resize handles onto [canvas].
  void renderOverlay(Canvas canvas) {
    if (!_isEnabled) return;
    ArenaEditorPainter.render(
      canvas: canvas,
      selectedRect: selectedPlatformRect,
      handle: handle,
      activeGizmo: _activeGizmo,
      isHandleHovered: _isHandleHovered,
      isResizing: _dragMode == EditorDragMode.resize,
    );
  }
}
