import 'package:flame/extensions.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:builds_and_bosses_flame/core/arena/arena_layout_blueprint.dart';
import 'package:builds_and_bosses_flame/game/components/arena_editor_component.dart';
import 'package:builds_and_bosses_flame/game/components/arena_map_component.dart';
import 'package:builds_and_bosses_flame/game/editor/arena_editor_controller.dart';
import 'package:builds_and_bosses_flame/game/game_input_controller.dart';
import 'package:builds_and_bosses_flame/game/tactical_game.dart';

class _FakeInputTarget implements GameInputTarget {
  bool characterBuilderActive = false;
  bool levelEditorActive = false;
  bool devModeToggled = false;
  GamePhase phase = GamePhase.realtime;

  @override
  bool get isCharacterBuilderActive => characterBuilderActive;

  @override
  bool get isLevelEditorActive => levelEditorActive;

  @override
  GamePhase get currentPhase => phase;

  @override
  void openCharacterBuilder() => characterBuilderActive = true;

  @override
  void closeCharacterBuilder() => characterBuilderActive = false;

  @override
  void openLevelEditor() => levelEditorActive = true;

  @override
  void closeLevelEditor() => levelEditorActive = false;

  @override
  void toggleLevelEditor() => levelEditorActive = !levelEditorActive;

  @override
  void toggleDeveloperMode() => devModeToggled = true;

  @override
  void cancelPlanning() {}

  @override
  void cycleCombatMode() {}

  @override
  void dropDown() {}

  @override
  void jump() {}

  @override
  void selectAbilityTargetAt(Vector2 worldPos) {}

  @override
  void selectAction(dynamic action) {}

  @override
  void selectHotbarSlot(int slot) {}

  @override
  void setHorizontalInput(double input) {}

  @override
  void setVerticalFlightInput(double input) {}

  @override
  void startAutoCombat() {}

  @override
  void startPlanning() {}

  @override
  void toggleDarkness() {}

  @override
  void triggerSelectedCombatHotkey() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Level Editor Game Integration', () {
    test(
      'GameInputController handles F4 to toggle and Escape to exit editor',
      () {
        final target = _FakeInputTarget();
        final input = GameInputController(target: target);

        expect(target.isLevelEditorActive, isFalse);

        // Press F4 -> opens level editor
        final f4Down = KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.f4,
          logicalKey: LogicalKeyboardKey.f4,
          timeStamp: Duration.zero,
        );
        final r1 = input.handleKeyEvent(f4Down, {LogicalKeyboardKey.f4});
        expect(r1, KeyEventResult.handled);
        expect(target.isLevelEditorActive, isTrue);

        // Press Escape while editor active -> closes level editor
        final escDown = KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.escape,
          logicalKey: LogicalKeyboardKey.escape,
          timeStamp: Duration.zero,
        );
        final r2 = input.handleKeyEvent(escDown, {LogicalKeyboardKey.escape});
        expect(r2, KeyEventResult.handled);
        expect(target.isLevelEditorActive, isFalse);
      },
    );

    test(
      'ArenaEditorComponent only intercepts pointer events when enabled',
      () {
        final blueprint = ArenaLayoutBlueprint.defaultArena();
        final controller = ArenaEditorController(blueprint: blueprint);
        final component = ArenaEditorComponent(
          controller: controller,
          arenaSize: Vector2(2400, 900),
        );

        expect(controller.isEnabled, isFalse);
        expect(component.containsLocalPoint(Vector2(500, 500)), isFalse);

        controller.isEnabled = true;
        expect(component.containsLocalPoint(Vector2(500, 500)), isTrue);
        expect(component.containsLocalPoint(Vector2(2500, 500)), isFalse);
      },
    );

    test('ArenaMapComponent applies custom blueprint platforms correctly', () {
      final blueprint = ArenaLayoutBlueprint(
        name: 'Custom Trial Arena',
        arenaWidth: 2400,
        arenaHeight: 900,
        platforms: [
          PlatformBlueprint(
            id: 'custom_plat_1',
            type: PlatformType.staticStone,
            x: 200,
            y: 500,
            width: 300,
            height: 25,
          ),
          PlatformBlueprint(
            id: 'custom_plat_moving',
            type: PlatformType.movingStone,
            x: 600,
            y: 400,
            width: 150,
            height: 20,
            kinematics: const PlatformKinematics(
              travelDistance: 200,
              directionX: 1.0,
              speed: 100,
            ),
          ),
        ],
      );

      final game = TacticalModeGame();
      game.arena = ArenaMapComponent(arenaWidth: 2400, arenaHeight: 900);
      game.arena.applyBlueprint(blueprint);

      expect(game.arena.staticPlatforms.length, equals(1));
      expect(game.arena.staticPlatforms.first.left, equals(200));
      expect(game.arena.staticPlatforms.first.width, equals(300));

      expect(game.arena.movingPlatform.position.x, equals(600));
      expect(game.arena.movingPlatform.minX, equals(600));
      expect(game.arena.movingPlatform.maxX, equals(800));
    });

    test(
      'TacticalModeGame openLevelEditor and closeLevelEditor cycle correctly',
      () {
        final game = TacticalModeGame();
        game.overlays.addEntry(
          'levelEditor',
          (context, game) => const SizedBox.shrink(),
        );
        expect(game.isLevelEditorActive, isFalse);
        expect(game.editorController.isEnabled, isFalse);

        game.openLevelEditor();
        expect(game.isLevelEditorActive, isTrue);
        expect(game.editorController.isEnabled, isTrue);

        game.closeLevelEditor();
        expect(game.isLevelEditorActive, isFalse);
        expect(game.editorController.isEnabled, isFalse);
      },
    );
  });
}
