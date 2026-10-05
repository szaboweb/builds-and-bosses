import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:builds_and_bosses_flame/core/arena/arena_layout_blueprint.dart';
import 'package:builds_and_bosses_flame/game/editor/arena_editor_controller.dart';
import 'package:builds_and_bosses_flame/ui/editor/level_editor_overlay.dart';
import 'package:builds_and_bosses_flame/ui/editor/palette_card_widget.dart';

void main() {
  group('PaletteCardWidget', () {
    testWidgets('renders label, subtitle, and responds to tap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaletteCardWidget(
              icon: Icons.crop_16_9,
              label: 'Kőplatform',
              subtitle: 'Statikus terep',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Kőplatform'), findsOneWidget);
      expect(find.text('Statikus terep'), findsOneWidget);
      expect(find.byIcon(Icons.crop_16_9), findsOneWidget);

      await tester.tap(find.text('Kőplatform'));
      expect(tapped, isTrue);
    });
  });

  group('LevelEditorOverlay', () {
    late ArenaLayoutBlueprint blueprint;
    late ArenaEditorController controller;

    setUp(() {
      blueprint = ArenaLayoutBlueprint(
        name: 'Test Level Arena',
        platforms: [
          PlatformBlueprint(
            id: 'plat_1',
            type: PlatformType.staticStone,
            x: 100.0,
            y: 200.0,
            width: 160.0,
            height: 20.0,
          ),
        ],
      );

      controller = ArenaEditorController(blueprint: blueprint, enabled: true);
    });

    testWidgets('renders top bar with name, grid toggle, and play button', (
      tester,
    ) async {
      var played = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelEditorOverlay(
              controller: controller,
              onPlayTest: () => played = true,
            ),
          ),
        ),
      );

      expect(find.text('Test Level Arena'), findsOneWidget);
      expect(find.text('1 db platform'), findsOneWidget);
      expect(find.text('Rács: 16px'), findsOneWidget);

      // Toggle grid
      await tester.tap(find.byKey(const Key('editor_grid_toggle_button')));
      await tester.pump();
      expect(controller.snapToGrid, isFalse);
      expect(find.text('Rács: KI'), findsOneWidget);

      // Tap Play/Test
      await tester.tap(find.byKey(const Key('editor_play_test_button')));
      expect(played, isTrue);
    });

    testWidgets('shows selection action cluster when platform is selected', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 720);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LevelEditorOverlay(controller: controller)),
        ),
      );

      // Initially no platform selected
      expect(
        find.byKey(const Key('editor_motion_toggle_button')),
        findsNothing,
      );

      // Select plat_1
      controller.selectPlatform('plat_1');
      await tester.pump();

      expect(find.text('160×20'), findsOneWidget);
      expect(
        find.byKey(const Key('editor_motion_toggle_button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('editor_duplicate_button')), findsOneWidget);
      expect(find.byKey(const Key('editor_delete_button')), findsOneWidget);

      // Toggle motion
      await tester.tap(find.byKey(const Key('editor_motion_toggle_button')));
      await tester.pump();
      expect(controller.selectedPlatform!.isMoving, isTrue);

      // Duplicate
      await tester.tap(find.byKey(const Key('editor_duplicate_button')));
      await tester.pump();
      expect(controller.platformCount, 2);

      // Delete selected
      await tester.tap(find.byKey(const Key('editor_delete_button')));
      await tester.pump();
      expect(controller.platformCount, 1);
      expect(controller.selectedPlatformId, isNull);
    });

    testWidgets('tapping palette cards adds platforms to layout', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LevelEditorOverlay(controller: controller)),
        ),
      );

      expect(controller.platformCount, 1);

      // Add static stone from palette
      await tester.tap(find.byKey(const Key('palette_static_stone')));
      await tester.pump();
      expect(controller.platformCount, 2);

      // Add moving stone from palette
      await tester.tap(find.byKey(const Key('palette_moving_stone')));
      await tester.pump();
      expect(controller.platformCount, 3);
      expect(controller.selectedPlatform!.isMoving, isTrue);
    });

    testWidgets('collapses and expands palette drawer on toggle', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LevelEditorOverlay(controller: controller)),
        ),
      );

      expect(find.byKey(const Key('palette_static_stone')), findsOneWidget);

      // Toggle to collapse
      await tester.tap(find.byKey(const Key('editor_drawer_toggle')));
      await tester.pumpAndSettle();

      // Drawer is collapsed
      expect(find.byKey(const Key('palette_static_stone')), findsNothing);

      // Toggle to expand
      await tester.tap(find.byKey(const Key('editor_drawer_toggle')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('palette_static_stone')), findsOneWidget);
    });
  });
}
