import 'package:flame/extensions.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:builds_and_bosses_flame/core/actions/game_action.dart';
import 'package:builds_and_bosses_flame/game/game_input_controller.dart';
import 'package:builds_and_bosses_flame/game/game_phase.dart';

class _FakeGameInputTarget implements GameInputTarget {
  @override
  bool isCharacterBuilderActive = false;

  @override
  GamePhase currentPhase = GamePhase.realtime;

  bool openedBuilder = false;
  bool closedBuilder = false;
  bool toggledDev = false;
  bool startedAutoCombat = false;
  bool triggeredHotkey = false;
  int? selectedHotbar;
  bool toggledDarkness = false;
  bool cycledCombatMode = false;
  ActionType? selectedAction;
  bool startedPlanning = false;
  bool canceledPlanning = false;
  bool jumped = false;
  bool droppedDown = false;
  double horizontalInput = 0;
  double verticalFlightInput = 0;
  Vector2? targetedAbilityPos;

  @override
  void openCharacterBuilder() => openedBuilder = true;

  @override
  void closeCharacterBuilder() => closedBuilder = true;

  @override
  void toggleDeveloperMode() => toggledDev = true;

  @override
  void startAutoCombat() => startedAutoCombat = true;

  @override
  void triggerSelectedCombatHotkey() => triggeredHotkey = true;

  @override
  void selectHotbarSlot(int slot) => selectedHotbar = slot;

  @override
  void toggleDarkness() => toggledDarkness = true;

  @override
  void cycleCombatMode() => cycledCombatMode = true;

  @override
  void selectAction(ActionType action) => selectedAction = action;

  @override
  void startPlanning() => startedPlanning = true;

  @override
  void cancelPlanning() => canceledPlanning = true;

  @override
  void jump() => jumped = true;

  @override
  void dropDown() => droppedDown = true;

  @override
  void setHorizontalInput(double input) => horizontalInput = input;

  @override
  void setVerticalFlightInput(double input) => verticalFlightInput = input;

  @override
  void selectAbilityTargetAt(Vector2 worldPos) => targetedAbilityPos = worldPos;
}

void main() {
  group('GameInputController', () {
    late _FakeGameInputTarget target;
    late GameInputController controller;

    setUp(() {
      target = _FakeGameInputTarget();
      controller = GameInputController(target: target);
    });

    test('tap down targets ability when in planning mode', () {
      target.currentPhase = GamePhase.planning;
      controller.handleTapDown(Vector2(100, 200), (local) => local * 2);
      expect(target.targetedAbilityPos, equals(Vector2(200, 400)));
    });

    test('tap down does not target ability when in realtime mode', () {
      target.currentPhase = GamePhase.realtime;
      controller.handleTapDown(Vector2(100, 200), (local) => local * 2);
      expect(target.targetedAbilityPos, isNull);
    });

    test('tap down does not target ability when character builder is open', () {
      target.currentPhase = GamePhase.planning;
      target.isCharacterBuilderActive = true;
      controller.handleTapDown(Vector2(100, 200), (local) => local * 2);
      expect(target.targetedAbilityPos, isNull);
    });

    test('Space key triggers jump in realtime mode', () {
      final result = controller.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.space,
          logicalKey: LogicalKeyboardKey.space,
          timeStamp: Duration.zero,
        ),
        {LogicalKeyboardKey.space},
      );
      expect(result, equals(KeyEventResult.handled));
      expect(target.jumped, isTrue);
    });

    test('Enter key starts planning when in realtime mode', () {
      final result = controller.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.enter,
          logicalKey: LogicalKeyboardKey.enter,
          timeStamp: Duration.zero,
        ),
        {LogicalKeyboardKey.enter},
      );
      expect(result, equals(KeyEventResult.handled));
      expect(target.startedPlanning, isTrue);
    });

    test('Escape key cancels planning when in planning mode', () {
      target.currentPhase = GamePhase.planning;
      final result = controller.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.escape,
          logicalKey: LogicalKeyboardKey.escape,
          timeStamp: Duration.zero,
        ),
        {LogicalKeyboardKey.escape},
      );
      expect(result, equals(KeyEventResult.handled));
      expect(target.canceledPlanning, isTrue);
    });

    test('B key toggles character builder open and close', () {
      controller.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyB,
          logicalKey: LogicalKeyboardKey.keyB,
          timeStamp: Duration.zero,
        ),
        {LogicalKeyboardKey.keyB},
      );
      expect(target.openedBuilder, isTrue);

      target.isCharacterBuilderActive = true;
      controller.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyB,
          logicalKey: LogicalKeyboardKey.keyB,
          timeStamp: Duration.zero,
        ),
        {LogicalKeyboardKey.keyB},
      );
      expect(target.closedBuilder, isTrue);
    });

    test('F3 key toggles developer mode', () {
      controller.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.f3,
          logicalKey: LogicalKeyboardKey.f3,
          timeStamp: Duration.zero,
        ),
        {LogicalKeyboardKey.f3},
      );
      expect(target.toggledDev, isTrue);
    });

    test('L key toggles darkness', () {
      controller.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyL,
          logicalKey: LogicalKeyboardKey.keyL,
          timeStamp: Duration.zero,
        ),
        {LogicalKeyboardKey.keyL},
      );
      expect(target.toggledDarkness, isTrue);
    });

    test('F key starts auto combat', () {
      controller.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyF,
          logicalKey: LogicalKeyboardKey.keyF,
          timeStamp: Duration.zero,
        ),
        {LogicalKeyboardKey.keyF},
      );
      expect(target.startedAutoCombat, isTrue);
    });

    test('R key triggers selected combat hotkey', () {
      controller.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyR,
          logicalKey: LogicalKeyboardKey.keyR,
          timeStamp: Duration.zero,
        ),
        {LogicalKeyboardKey.keyR},
      );
      expect(target.triggeredHotkey, isTrue);
    });

    test('Tab key cycles combat mode', () {
      controller.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.tab,
          logicalKey: LogicalKeyboardKey.tab,
          timeStamp: Duration.zero,
        ),
        {LogicalKeyboardKey.tab},
      );
      expect(target.cycledCombatMode, isTrue);
    });

    test('digit keys select hotbar slots during planning', () {
      target.currentPhase = GamePhase.planning;
      controller.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.digit3,
          logicalKey: LogicalKeyboardKey.digit3,
          timeStamp: Duration.zero,
        ),
        {LogicalKeyboardKey.digit3},
      );
      expect(target.selectedHotbar, equals(2));
    });
  });
}
