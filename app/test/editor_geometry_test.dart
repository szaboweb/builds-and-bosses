import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:builds_and_bosses_flame/core/arena/arena_layout_blueprint.dart';
import 'package:builds_and_bosses_flame/game/editor/arena_editor_controller.dart';
import 'package:builds_and_bosses_flame/game/editor/editor_corner_handle.dart';

void main() {
  group('EditorCornerHandle', () {
    const handle = EditorCornerHandle();
    final targetRect = const Rect.fromLTWH(100.0, 200.0, 160.0, 20.0);

    test('calculates correct handle rect centered at bottom-right corner', () {
      final rect = handle.getHandleRect(targetRect);

      expect(rect.center, const Offset(260.0, 220.0));
      expect(rect.width, EditorCornerHandle.handleSize);
      expect(rect.height, EditorCornerHandle.handleSize);
    });

    test('isHovering detects proximity within handle rect and padding', () {
      final center = Offset(targetRect.right, targetRect.bottom);

      expect(handle.isHovering(targetRect, center), isTrue);
      // Within 4px padding
      expect(
        handle.isHovering(targetRect, center + const Offset(9.0, 9.0)),
        isTrue,
      );
      // Far outside
      expect(
        handle.isHovering(targetRect, center + const Offset(30.0, 30.0)),
        isFalse,
      );
    });

    test('applyResize clamps to minimum bounds (64x16)', () {
      final resized = handle.applyResize(
        target: targetRect,
        currentMousePos: const Offset(110.0, 205.0), // Smaller than minimum
        gridSnap: 0.0,
      );

      expect(resized.left, 100.0);
      expect(resized.top, 200.0);
      expect(resized.width, EditorCornerHandle.minWidth);
      expect(resized.height, EditorCornerHandle.minHeight);
    });

    test('applyResize snaps to 16px grid intervals', () {
      // Delta x = 205 - 100 = 105 -> round(105 / 16) * 16 = 7 * 16 = 112
      // Delta y = 239 - 200 = 39 -> round(39 / 16) * 16 = 2 * 16 = 32
      final resized = handle.applyResize(
        target: targetRect,
        currentMousePos: const Offset(205.0, 239.0),
        gridSnap: 16.0,
      );

      expect(resized.width, 112.0);
      expect(resized.height, 32.0);
    });

    test('render executes without error on a Canvas', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => handle.render(canvas, targetRect), returnsNormally);
      expect(
        () => handle.render(
          canvas,
          targetRect,
          isHovered: true,
          isDragging: true,
        ),
        returnsNormally,
      );
    });
  });

  group('ArenaEditorController', () {
    late ArenaLayoutBlueprint blueprint;
    late ArenaEditorController controller;

    setUp(() {
      blueprint = ArenaLayoutBlueprint(
        arenaWidth: 1000.0,
        arenaHeight: 600.0,
        platforms: [
          PlatformBlueprint(
            id: 'plat_1',
            type: PlatformType.staticStone,
            x: 100.0,
            y: 200.0,
            width: 160.0,
            height: 20.0,
          ),
          PlatformBlueprint(
            id: 'plat_2',
            type: PlatformType.movingStone,
            x: 400.0,
            y: 300.0,
            width: 180.0,
            height: 24.0,
          ),
        ],
      );

      controller = ArenaEditorController(blueprint: blueprint, enabled: true);
    });

    test('does not process pointer events when isEnabled is false', () {
      controller.isEnabled = false;
      final handled = controller.handlePointerDown(const Offset(120.0, 210.0));

      expect(handled, isFalse);
      expect(controller.selectedPlatformId, isNull);
    });

    test('selects platform on tap and clears on tapping empty space', () {
      // Tap on plat_1
      final hit1 = controller.handlePointerDown(const Offset(150.0, 210.0));
      expect(hit1, isTrue);
      expect(controller.selectedPlatformId, 'plat_1');
      expect(
        controller.selectedPlatformRect,
        const Rect.fromLTWH(100.0, 200.0, 160.0, 20.0),
      );

      controller.handlePointerUp();

      // Tap on empty space
      final hitEmpty = controller.handlePointerDown(const Offset(50.0, 50.0));
      expect(hitEmpty, isFalse);
      expect(controller.selectedPlatformId, isNull);
      expect(controller.selectedPlatformRect, isNull);
    });

    test('drags corner handle to resize selected platform', () {
      // Select plat_1
      controller.handlePointerDown(const Offset(150.0, 210.0));
      controller.handlePointerUp();

      // Handle center is at (260, 220)
      final handlePos = Offset(
        controller.selectedPlatformRect!.right,
        controller.selectedPlatformRect!.bottom,
      );

      final hitHandle = controller.handlePointerDown(handlePos);
      expect(hitHandle, isTrue);
      expect(controller.dragMode, EditorDragMode.resize);

      // Drag to extend width to 240 (100 + 240 = 340) and height to 32 (200 + 32 = 232)
      final moved = controller.handlePointerMove(const Offset(340.0, 232.0));
      expect(moved, isTrue);

      final plat = controller.selectedPlatform!;
      expect(plat.width, 240.0);
      expect(plat.height, 32.0);

      controller.handlePointerUp();
      expect(controller.dragMode, EditorDragMode.none);
    });

    test(
      'drags platform body to reposition with grid snapping and arena clamping',
      () {
        // Pointer down on plat_1 body at (120, 210)
        controller.handlePointerDown(const Offset(120.0, 210.0));
        expect(controller.dragMode, EditorDragMode.move);

        // Drag delta = +32px on X, +16px on Y
        controller.handlePointerMove(const Offset(152.0, 226.0));

        final plat = controller.selectedPlatform!;
        expect(
          plat.x,
          128.0,
        ); // 100 + 32 = 132 -> snapped to 16px grid is 128.0
        expect(
          plat.y,
          224.0,
        ); // 200 + 16 = 216 -> (216/16 = 13.5) -> snapped to 224.0
      },
    );

    test('adds, duplicates, and removes platforms', () {
      expect(controller.platformCount, 2);

      // Add
      final added = controller.addPlatform(
        type: PlatformType.staticStone,
        x: 50.0,
        y: 80.0,
      );
      expect(controller.platformCount, 3);
      expect(controller.selectedPlatformId, added.id);

      // Duplicate
      final cloned = controller.duplicateSelectedPlatform(
        offsetX: 16.0,
        offsetY: 16.0,
      );
      expect(cloned, isNotNull);
      expect(controller.platformCount, 4);
      expect(controller.selectedPlatformId, cloned!.id);
      expect(cloned.x, 66.0);

      // Remove
      final removed = controller.removeSelectedPlatform();
      expect(removed, isTrue);
      expect(controller.platformCount, 3);
      expect(controller.selectedPlatformId, isNull);
    });

    test('renderOverlay draws without throwing when platform is selected', () {
      controller.selectPlatform('plat_1');

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => controller.renderOverlay(canvas), returnsNormally);
    });
  });
}
