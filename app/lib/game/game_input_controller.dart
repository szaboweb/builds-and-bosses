import 'package:flame/extensions.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/actions/game_action.dart';
import 'game_phase.dart';

/// Contract for dispatching player and tactical intent from raw input devices.
/// Implemented by TacticalModeGame per docs/ARCHITECTURE.md.
abstract interface class GameInputTarget {
  bool get isCharacterBuilderActive;
  bool get isLevelEditorActive;
  GamePhase get currentPhase;

  void openCharacterBuilder();
  void closeCharacterBuilder();
  void openLevelEditor();
  void closeLevelEditor();
  void toggleLevelEditor();
  void toggleDeveloperMode();
  void startAutoCombat();
  void triggerSelectedCombatHotkey();
  void selectHotbarSlot(int slot);
  void toggleDarkness();
  void cycleCombatMode();
  void selectAction(ActionType action);
  void startPlanning();
  void cancelPlanning();
  void jump();
  void dropDown();
  void setHorizontalInput(double input);
  void setVerticalFlightInput(double input);
  void selectAbilityTargetAt(Vector2 worldPos);
}

/// Decouples keyboard, mouse and pointer input from the game coordinator.
/// Normalizes key and tap events into gameplay intent and dispatches them to [GameInputTarget].
class GameInputController {
  final GameInputTarget target;

  const GameInputController({required this.target});

  /// Handles tap down in the world, dispatching ability targeting when planning.
  void handleTapDown(
    Vector2 localPosition,
    Vector2 Function(Vector2 local) globalToLocal,
  ) {
    if (target.isCharacterBuilderActive || target.isLevelEditorActive) return;
    if (target.currentPhase == GamePhase.planning) {
      final worldPos = globalToLocal(localPosition);
      target.selectAbilityTargetAt(worldPos);
    }
  }

  /// Handles key events across realtime, planning, and editor states.
  KeyEventResult handleKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final globalResult = _handleGlobalShortcuts(event);
    if (globalResult != null) return globalResult;

    if (target.isCharacterBuilderActive) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        target.closeCharacterBuilder();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (target.isLevelEditorActive) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        target.closeLevelEditor();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (target.currentPhase == GamePhase.planning) {
      final planningResult = _handlePlanningKeys(event);
      if (planningResult != null) return planningResult;
    }

    if (target.currentPhase == GamePhase.realtime) {
      return _handleRealtimeKeys(event, keysPressed);
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult? _handleGlobalShortcuts(KeyEvent event) {
    if (event is! KeyDownEvent) return null;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.keyB) {
      if (target.isCharacterBuilderActive) {
        target.closeCharacterBuilder();
      } else {
        target.openCharacterBuilder();
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.f3) {
      target.toggleDeveloperMode();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.f4) {
      target.toggleLevelEditor();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyF) {
      target.startAutoCombat();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyR ||
        key == LogicalKeyboardKey.altGraph ||
        key == LogicalKeyboardKey.altRight) {
      target.triggerSelectedCombatHotkey();
      return KeyEventResult.handled;
    }

    final slot = _hotbarSlotForKey(key);
    if (slot != null) {
      target.selectHotbarSlot(slot);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyL) {
      target.toggleDarkness();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.tab) {
      target.cycleCombatMode();
      return KeyEventResult.handled;
    }

    return null;
  }

  KeyEventResult? _handlePlanningKeys(KeyEvent event) {
    if (event is! KeyDownEvent) return null;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.keyQ ||
        key == LogicalKeyboardKey.controlRight) {
      target.selectAction(ActionType.dash);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.escape) {
      target.cancelPlanning();
      return KeyEventResult.handled;
    }

    return null;
  }

  KeyEventResult _handleRealtimeKeys(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        target.startPlanning();
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.space) {
        target.jump();
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.keyS ||
          key == LogicalKeyboardKey.arrowDown) {
        target.dropDown();
      }
    }

    // Horizontal run input (A / D / Left / Right)
    double horizontal = 0.0;
    if (keysPressed.contains(LogicalKeyboardKey.keyA) ||
        keysPressed.contains(LogicalKeyboardKey.arrowLeft)) {
      horizontal -= 1.0;
    }
    if (keysPressed.contains(LogicalKeyboardKey.keyD) ||
        keysPressed.contains(LogicalKeyboardKey.arrowRight)) {
      horizontal += 1.0;
    }
    target.setHorizontalInput(horizontal);

    // Vertical flight input (W / S / Up / Down)
    double vertical = 0.0;
    if (keysPressed.contains(LogicalKeyboardKey.keyW) ||
        keysPressed.contains(LogicalKeyboardKey.arrowUp)) {
      vertical -= 1.0;
    }
    if (keysPressed.contains(LogicalKeyboardKey.keyS) ||
        keysPressed.contains(LogicalKeyboardKey.arrowDown)) {
      vertical += 1.0;
    }
    target.setVerticalFlightInput(vertical);

    return KeyEventResult.ignored;
  }

  int? _hotbarSlotForKey(LogicalKeyboardKey key) {
    const keys = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
      LogicalKeyboardKey.digit0,
    ];
    final index = keys.indexOf(key);
    return index == -1 ? null : index;
  }
}
