import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/actions/action_queue.dart';
import '../core/actions/game_action.dart';
import '../core/campaign/campaign_blueprint.dart';
import '../core/combat/combat_logger.dart';
import '../core/dnd/character_stats.dart';
import 'components/arena_map_component.dart';
import 'components/dummy_enemy_component.dart';
import 'components/ghost_preview_component.dart';
import 'components/player_component.dart';

enum GamePhase { realtime, planning, executing, cooldown }

/// The main Flame game instance integrating the Side-view Platformer arena,
/// gravity physics, player jumping, enemy dummy, and Tactical Mode planning loop.
class TacticalModeGame extends FlameGame with KeyboardEvents, TapCallbacks {
  late ArenaMapComponent arena;
  late PlayerComponent player;
  late DummyEnemyComponent enemy;
  late GhostPreviewComponent ghostPreview;

  final ActionQueue actionQueue = ActionQueue(maxAP: 100);

  // Observable state for Flutter UI widgets
  final ValueNotifier<GamePhase> phaseNotifier = ValueNotifier<GamePhase>(
    GamePhase.realtime,
  );
  final ValueNotifier<ActionType> selectedActionNotifier =
      ValueNotifier<ActionType>(ActionType.slash);
  CampaignBlueprint? activeBlueprint;

  GamePhase get currentPhase => phaseNotifier.value;

  @override
  Color backgroundColor() => const Color(0xFF0D0B14);

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // 1. Arena Map (Side-view gothic dungeon with elevated platforms & torches)
    arena = ArenaMapComponent(arenaWidth: 960, arenaHeight: 540);
    add(arena);

    // 2. Player (Knight protagonist with gravity and dynamic stat-driven jumping)
    player = PlayerComponent(
      position: Vector2(180, arena.groundY - 26),
      movementBounds: arena.playableBounds,
    );
    add(player);

    // 3. Enemy Dummy / Vanguard (Placed on right lower platform)
    enemy = DummyEnemyComponent(
      position: Vector2(arena.size.x - 200, arena.size.y - 155 - 26),
      onTapped: () {
        if (currentPhase == GamePhase.planning) {
          queueAttackOnEnemy();
        }
      },
    );
    add(enemy);

    // 4. Ghost Preview Component for Tactical Mode
    ghostPreview = GhostPreviewComponent(player: player, queue: actionQueue);
    add(ghostPreview);

    // Center camera on the arena
    camera.viewfinder.position = arena.size / 2;
    camera.viewfinder.anchor = Anchor.center;
  }

  // --- Phase Controls ---

  void startPlanning() {
    if (currentPhase != GamePhase.realtime) return;
    phaseNotifier.value = GamePhase.planning;
    player.velocity = Vector2.zero();
    actionQueue.clear();
    selectedActionNotifier.value = ActionType.slash;
    overlays.add('actionBar');
    CombatLogger.instance.logPhaseChange(
      fromPhase: 'REALTIME',
      toPhase: 'PLANNING',
    );
  }

  void cancelPlanning() {
    if (currentPhase != GamePhase.planning) return;
    actionQueue.clear();
    phaseNotifier.value = GamePhase.realtime;
    overlays.remove('actionBar');
    CombatLogger.instance.logPhaseChange(
      fromPhase: 'PLANNING',
      toPhase: 'REALTIME',
    );
  }

  void executePlan() {
    if (currentPhase != GamePhase.planning) return;
    if (actionQueue.isEmpty) {
      cancelPlanning();
      return;
    }

    phaseNotifier.value = GamePhase.executing;
    overlays.remove('actionBar');
    CombatLogger.instance.logPhaseChange(
      fromPhase: 'PLANNING',
      toPhase: 'EXECUTING',
    );

    player.executePlan(actionQueue.actions, () {
      actionQueue.clear();
      phaseNotifier.value = GamePhase.realtime;
      CombatLogger.instance.logPhaseChange(
        fromPhase: 'EXECUTING',
        toPhase: 'REALTIME',
      );
    });
  }

  // --- Character Builder (Tervezőasztal) Controls ---

  void openCharacterBuilder() {
    player.velocity = Vector2.zero();
    overlays.add('characterBuilder');
    CombatLogger.instance.logPhaseChange(
      fromPhase: currentPhase.name.toUpperCase(),
      toPhase: 'BUILDER',
    );
  }

  void closeCharacterBuilder() {
    overlays.remove('characterBuilder');
    CombatLogger.instance.logPhaseChange(
      fromPhase: 'BUILDER',
      toPhase: currentPhase.name.toUpperCase(),
    );
  }

  void applyHeroBuild(CharacterStats newStats, {CampaignBlueprint? blueprint}) {
    final oldStats = player.stats;
    player.updateStats(newStats);
    activeBlueprint = blueprint;
    CombatLogger.instance.logBuildChange(
      oldStats: oldStats,
      newStats: newStats,
    );
    closeCharacterBuilder();
  }

  // --- Action Queueing ---

  void queueAttackOnEnemy() {
    if (currentPhase != GamePhase.planning) return;
    final action = SlashAction(targetPosition: enemy.position.clone());
    _tryAddAction(action);
  }

  void queueActionAt(Vector2 tapPosition) {
    if (currentPhase != GamePhase.planning) return;

    final actionType = selectedActionNotifier.value;
    final GameAction action;
    switch (actionType) {
      case ActionType.move:
        action = MoveAction(targetPosition: tapPosition);
        break;
      case ActionType.slash:
        action = SlashAction(targetPosition: tapPosition);
        break;
      case ActionType.dash:
        action = DashAction(targetPosition: tapPosition);
        break;
      case ActionType.heal:
        action = HealAction();
        break;
    }
    _tryAddAction(action);
  }

  void _tryAddAction(GameAction action) {
    final success = actionQueue.tryAdd(action);
    if (success) {
      CombatLogger.instance.logTacticalAction(
        eventType: 'QUEUED',
        action: action,
        spentAP: actionQueue.spentAP,
        remainingAP: actionQueue.remainingAP,
      );
    } else {
      CombatLogger.instance.logWarning(
        'TACTICAL',
        'Cannot queue ${action.name} (Cost: ${action.apCost} AP): Insufficient AP (${actionQueue.remainingAP} remaining)',
      );
    }
  }

  void undoLastAction() {
    final undone = actionQueue.undo();
    if (undone != null) {
      CombatLogger.instance.logTacticalAction(
        eventType: 'UNDONE',
        action: undone,
        spentAP: actionQueue.spentAP,
        remainingAP: actionQueue.remainingAP,
      );
    }
  }

  // --- Input Handling ---

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (overlays.isActive('characterBuilder')) return;

    final worldPos = camera.globalToLocal(event.localPosition);

    if (currentPhase == GamePhase.planning) {
      queueActionAt(worldPos);
    } else if (currentPhase == GamePhase.realtime) {
      // Tap to jump or run horizontally in realtime
      if (worldPos.y < player.position.y - 30) {
        player.jump();
      }
      final diffX = worldPos.x - player.position.x;
      if (diffX.abs() > 20) {
        player.velocity.x = diffX > 0 ? 1.0 : -1.0;
      }
    }
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    // 0. Toggle Character Builder on 'B' key
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyB) {
      if (overlays.isActive('characterBuilder')) {
        closeCharacterBuilder();
      } else {
        openCharacterBuilder();
      }
      return KeyEventResult.handled;
    }

    if (overlays.isActive('characterBuilder')) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        closeCharacterBuilder();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // 1. Enter toggles Tactical Mode planning / returns to realtime
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
      if (currentPhase == GamePhase.realtime) {
        startPlanning();
        return KeyEventResult.handled;
      } else if (currentPhase == GamePhase.planning) {
        cancelPlanning();
        return KeyEventResult.handled;
      }
    }

    // 2. SPACE executes during Planning, or Jumps in Realtime
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
      if (currentPhase == GamePhase.planning) {
        executePlan();
        return KeyEventResult.handled;
      } else if (currentPhase == GamePhase.realtime) {
        player.jump();
        return KeyEventResult.handled;
      }
    }

    // 3. Escape cancels planning
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      if (currentPhase == GamePhase.planning) {
        cancelPlanning();
        return KeyEventResult.handled;
      }
    }

    // 4. Realtime Platformer Controls
    if (currentPhase == GamePhase.realtime) {
      // Jump on W or Up arrow
      if (event is KeyDownEvent &&
          (event.logicalKey == LogicalKeyboardKey.keyW ||
              event.logicalKey == LogicalKeyboardKey.arrowUp)) {
        player.jump();
        return KeyEventResult.handled;
      }

      // Drop down through platform on S or Down arrow
      if (event is KeyDownEvent &&
          (event.logicalKey == LogicalKeyboardKey.keyS ||
              event.logicalKey == LogicalKeyboardKey.arrowDown)) {
        player.dropDown();
        return KeyEventResult.handled;
      }

      // Horizontal run (A / D / Left / Right)
      double horizontalInput = 0.0;
      if (keysPressed.contains(LogicalKeyboardKey.keyA) ||
          keysPressed.contains(LogicalKeyboardKey.arrowLeft)) {
        horizontalInput -= 1.0;
      }
      if (keysPressed.contains(LogicalKeyboardKey.keyD) ||
          keysPressed.contains(LogicalKeyboardKey.arrowRight)) {
        horizontalInput += 1.0;
      }

      player.velocity.x = horizontalInput;
    }

    return KeyEventResult.ignored;
  }
}
