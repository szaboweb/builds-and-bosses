import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:builds_and_bosses_flame/core/arena/arena_layout_blueprint.dart';
import 'package:builds_and_bosses_flame/game/editor/arena_editor_controller.dart';
import 'package:builds_and_bosses_flame/game/editor/motion_vector_gizmo.dart';

void main() {
  group('MotionVectorGizmo', () {
    test('computes distance and horizontal direction correctly', () {
      final gizmoRight = MotionVectorGizmo(
        startPoint: const Offset(100.0, 200.0),
        currentEndPoint: const Offset(260.0, 200.0),
      );
      expect(gizmoRight.distance, 160.0);
      expect(gizmoRight.directionX, 1.0);

      final gizmoLeft = MotionVectorGizmo(
        startPoint: const Offset(200.0, 200.0),
        currentEndPoint: const Offset(80.0, 200.0),
      );
      expect(gizmoLeft.distance, 120.0);
      expect(gizmoLeft.directionX, -1.0);
    });

    test('creates gizmo from moving PlatformBlueprint', () {
      final platform = PlatformBlueprint(
        id: 'plat_move',
        type: PlatformType.movingStone,
        x: 100.0,
        y: 200.0,
        width: 160.0,
        height: 20.0,
        kinematics: const PlatformKinematics(
          travelDistance: 128.0,
          directionX: 1.0,
          speed: 90.0,
        ),
      );

      final gizmo = MotionVectorGizmo.fromPlatform(platform);
      // Platform center is (100 + 80, 200 + 10) = (180, 210)
      expect(gizmo.startPoint, const Offset(180.0, 210.0));
      // End point is (180 + 128, 210) = (308, 210)
      expect(gizmo.currentEndPoint, const Offset(308.0, 210.0));
      expect(gizmo.distance, 128.0);
      expect(gizmo.directionX, 1.0);
    });

    test('updateEnd snaps to 16px grid intervals and locks horizontally', () {
      final gizmo = MotionVectorGizmo(
        startPoint: const Offset(100.0, 200.0),
        currentEndPoint: const Offset(100.0, 200.0),
      );

      // Pointer at (205, 250) -> deltaX = 105 -> round(105 / 16) * 16 = 112
      gizmo.updateEnd(
        const Offset(205.0, 250.0),
        gridSnap: 16.0,
        lockHorizontal: true,
      );

      expect(gizmo.currentEndPoint.dx, 212.0); // 100 + 112 = 212
      expect(gizmo.currentEndPoint.dy, 200.0); // Y remains locked
      expect(gizmo.distance, 112.0);
    });

    test('updateOrigin displaces start and end while preserving distance and direction', () {
      final gizmo = MotionVectorGizmo(
        startPoint: const Offset(100.0, 200.0),
        currentEndPoint: const Offset(260.0, 200.0),
      );
      expect(gizmo.distance, 160.0);

      gizmo.updateOrigin(const Offset(150.0, 250.0));

      expect(gizmo.startPoint, const Offset(150.0, 250.0));
      expect(gizmo.currentEndPoint, const Offset(310.0, 250.0));
      expect(gizmo.distance, 160.0);
      expect(gizmo.directionX, 1.0);
    });

    test('applyToPlatform commits kinematics and updates platform type', () {
      final platform = PlatformBlueprint(
        id: 'plat_test',
        type: PlatformType.staticStone,
        x: 100.0,
        y: 200.0,
        width: 160.0,
        height: 20.0,
      );

      final gizmo = MotionVectorGizmo(
        startPoint: const Offset(180.0, 210.0),
        currentEndPoint: const Offset(340.0, 210.0),
      );

      gizmo.applyToPlatform(platform, speed: 120.0);

      expect(platform.type, PlatformType.movingStone);
      expect(platform.travelDistance, 160.0);
      expect(platform.directionX, 1.0);
      expect(platform.speed, 120.0);
    });

    test('isTipHovering detects proximity to tip handle', () {
      final gizmo = MotionVectorGizmo(
        startPoint: const Offset(100.0, 200.0),
        currentEndPoint: const Offset(260.0, 200.0),
        handleRadius: 8.0,
      );

      expect(gizmo.isTipHovering(const Offset(260.0, 200.0)), isTrue);
      expect(
        gizmo.isTipHovering(const Offset(269.0, 200.0)),
        isTrue,
      ); // within 8+6 px
      expect(gizmo.isTipHovering(const Offset(280.0, 200.0)), isFalse);
    });

    test('render executes on Canvas without throwing', () {
      final gizmo = MotionVectorGizmo(
        startPoint: const Offset(100.0, 200.0),
        currentEndPoint: const Offset(260.0, 200.0),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => gizmo.render(canvas, pulse: 1.0), returnsNormally);
      expect(() => gizmo.render(canvas, isHovered: true), returnsNormally);
    });
  });

  group('ArenaEditorController Motion Gizmo Integration', () {
    late ArenaLayoutBlueprint blueprint;
    late ArenaEditorController controller;

    setUp(() {
      blueprint = ArenaLayoutBlueprint(
        platforms: [
          PlatformBlueprint(
            id: 'plat_static',
            type: PlatformType.staticStone,
            x: 100.0,
            y: 200.0,
            width: 160.0,
            height: 20.0,
          ),
          PlatformBlueprint(
            id: 'plat_moving',
            type: PlatformType.movingStone,
            x: 400.0,
            y: 300.0,
            width: 160.0,
            height: 20.0,
            kinematics: const PlatformKinematics(
              travelDistance: 160.0,
              directionX: 1.0,
              speed: 90.0,
            ),
          ),
        ],
      );

      controller = ArenaEditorController(blueprint: blueprint, enabled: true);
    });

    test('selecting a moving platform synchronizes activeGizmo', () {
      expect(controller.activeGizmo, isNull);

      controller.selectPlatform('plat_moving');
      expect(controller.activeGizmo, isNotNull);
      expect(controller.activeGizmo!.distance, 160.0);

      controller.selectPlatform('plat_static');
      expect(controller.activeGizmo, isNull);
    });

    test('dragging gizmo tip updates platform trajectory and distance', () {
      controller.selectPlatform('plat_moving');
      final gizmo = controller.activeGizmo!;

      // Gizmo tip is at (400 + 80 + 160, 300 + 10) = (640, 310)
      final tipPos = gizmo.currentEndPoint;
      expect(tipPos, const Offset(640.0, 310.0));

      final hitTip = controller.handlePointerDown(tipPos);
      expect(hitTip, isTrue);
      expect(controller.dragMode, EditorDragMode.dragVector);

      // Drag tip further to x = 720 (480 + 240 = 720)
      controller.handlePointerMove(const Offset(720.0, 310.0));

      final plat = controller.selectedPlatform!;
      expect(plat.travelDistance, 240.0);
      expect(gizmo.distance, 240.0);

      controller.handlePointerUp();
      expect(controller.dragMode, EditorDragMode.none);
      expect(gizmo.isDragging, isFalse);
    });

    test(
      'toggling motion converts static platform to moving and vice versa',
      () {
        controller.selectPlatform('plat_static');
        expect(controller.activeGizmo, isNull);
        expect(controller.selectedPlatform!.isMoving, isFalse);

        // Enable motion
        controller.toggleSelectedPlatformMotion(defaultDistance: 128.0);
        expect(controller.selectedPlatform!.isMoving, isTrue);
        expect(controller.selectedPlatform!.travelDistance, 128.0);
        expect(controller.activeGizmo, isNotNull);

        // Disable motion
        controller.toggleSelectedPlatformMotion();
        expect(controller.selectedPlatform!.isMoving, isFalse);
        expect(controller.activeGizmo, isNull);
      },
    );
  });
}
