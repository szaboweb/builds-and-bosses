import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:builds_and_bosses_flame/core/arena/arena_layout_blueprint.dart';
import 'package:builds_and_bosses_flame/core/arena/stalactite_cavern_layout.dart';
import 'package:builds_and_bosses_flame/ui/level_selector_overlay.dart';

void main() {
  group('LevelSelectorOverlay', () {
    testWidgets('renders title and level buttons', (tester) async {
      var selectedBlueprint = <ArenaLayoutBlueprint>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelSelectorOverlay(
              onLevelSelected: (blueprint) {
                selectedBlueprint.add(blueprint);
              },
            ),
          ),
        ),
      );

      // Check title
      expect(find.text('Select Level'), findsOneWidget);

      // Check both level buttons
      expect(find.text('Cathedral of Trials (Default)'), findsOneWidget);
      expect(find.text('Stalactite Cavern'), findsOneWidget);

      // Verify both buttons are clickable
      expect(find.byType(ElevatedButton), findsWidgets);
    });

    testWidgets('Cathedral of Trials button calls onLevelSelected', (
      tester,
    ) async {
      var selectedBlueprints = <ArenaLayoutBlueprint>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelSelectorOverlay(
              onLevelSelected: (blueprint) {
                selectedBlueprints.add(blueprint);
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Cathedral of Trials (Default)'));
      await tester.pump();

      expect(selectedBlueprints.length, 1);
      expect(selectedBlueprints[0].name, 'Cathedral of Trials');
      expect(selectedBlueprints[0].arenaWidth, 2400.0);
      expect(selectedBlueprints[0].arenaHeight, 900.0);
    });

    testWidgets('Stalactite Cavern button calls onLevelSelected', (
      tester,
    ) async {
      var selectedBlueprints = <ArenaLayoutBlueprint>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelSelectorOverlay(
              onLevelSelected: (blueprint) {
                selectedBlueprints.add(blueprint);
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Stalactite Cavern'));
      await tester.pump();

      expect(selectedBlueprints.length, 1);
      expect(selectedBlueprints[0].name, 'Stalactite Cavern');
      expect(selectedBlueprints[0].arenaWidth, 3000.0);
      expect(selectedBlueprints[0].arenaHeight, 1200.0);
    });

    testWidgets('Stalactite Cavern has correct platform count', (tester) async {
      var selectedBlueprints = <ArenaLayoutBlueprint>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelSelectorOverlay(
              onLevelSelected: (blueprint) {
                selectedBlueprints.add(blueprint);
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Stalactite Cavern'));
      await tester.pump();

      expect(selectedBlueprints.length, 1);
      expect(selectedBlueprints[0].platforms.length, greaterThan(0));
      // Verify platform IDs
      final platformIds = selectedBlueprints[0].platforms
          .map((p) => p.id)
          .toList();
      expect(platformIds, contains('plat_lower_left_main'));
      expect(platformIds, contains('plat_chasm_floor'));
    });

    testWidgets('both levels have spawn points defined', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LevelSelectorOverlay(onLevelSelected: (_) {})),
        ),
      );

      // Get both blueprints
      final defaultArena = ArenaLayoutBlueprint.defaultArena();
      final stalactite = StalactiteCavernLayout.stalactiteCavern();

      expect(defaultArena.playerSpawnX, greaterThan(0.0));
      expect(defaultArena.playerSpawnY, greaterThan(0.0));
      expect(stalactite.playerSpawnX, greaterThan(0.0));
      expect(stalactite.playerSpawnY, greaterThan(0.0));
    });
  });
}
