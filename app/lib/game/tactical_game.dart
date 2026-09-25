import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/actions/action_queue.dart';
import '../core/actions/action_cooldowns.dart';
import '../core/actions/game_action.dart';
import '../core/campaign/campaign_blueprint.dart';
import '../core/combat/combat_logger.dart';
import '../core/dnd/character_stats.dart';
import '../core/dnd/dice.dart';
import '../core/debug/debug_replay.dart';
import '../core/platform/platform_services.dart';
import '../platform/local_platform_services.dart';
import 'components/arena_map_component.dart';
import 'components/dummy_enemy_component.dart';
import 'components/ghost_preview_component.dart';
import 'components/player_component.dart';
import 'camera_follow_controller.dart';
import 'lighting_controller.dart';
import 'developer_mode_controller.dart';
import 'developer_visualization_component.dart';

enum GamePhase { realtime, planning, executing, cooldown }
enum CombatOutcome { victory, defeat }

/// The main Flame game instance integrating the Side-view Platformer arena,
/// gravity physics, player jumping, enemy dummy, and Tactical Mode planning loop.
class TacticalModeGame extends FlameGame with KeyboardEvents, TapCallbacks {
  final PlatformServices platformServices;
  final int debugSeed;

  TacticalModeGame({PlatformServices? platformServices, int? debugSeed})
    : platformServices = platformServices ?? LocalPlatformServices(),
      debugSeed = debugSeed ?? DateTime.now().millisecondsSinceEpoch;

  late ArenaMapComponent arena;
  late PlayerComponent player;
  late DummyEnemyComponent enemy;
  late GhostPreviewComponent ghostPreview;
  late CameraFollowController cameraFollowController;
  late LightingController lightingController;
  late DeveloperModeController developerModeController;
  late DateTime combatStartedAt;
  late DebugReplayRecorder replayRecorder;

  final ActionQueue actionQueue = ActionQueue(maxAP: 100);
  final ActionCooldowns actionCooldowns = ActionCooldowns();
  final ValueNotifier<int> debugTickNotifier = ValueNotifier<int>(0);
  bool get debugHudEnabled => developerModeController.enabled.value;

  // Observable state for Flutter UI widgets
  final ValueNotifier<GamePhase> phaseNotifier = ValueNotifier<GamePhase>(
    GamePhase.realtime,
  );
  final ValueNotifier<CombatOutcome?> combatOutcomeNotifier =
      ValueNotifier<CombatOutcome?>(null);
  final ValueNotifier<ActionType> selectedActionNotifier =
      ValueNotifier<ActionType>(ActionType.slash);
  CampaignBlueprint? activeBlueprint;

  GamePhase get currentPhase => phaseNotifier.value;

  @override
  Color backgroundColor() => const Color(0xFF0D0B14);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    combatStartedAt = DateTime.now();
    Dice.configureSeed(debugSeed);

    // 1. Arena Map (Side-view gothic dungeon with elevated platforms & torches)
    arena = ArenaMapComponent(arenaWidth: 2400, arenaHeight: 900);
    world.add(arena);

    // 2. Player (Knight protagonist with gravity and dynamic stat-driven jumping)
    player = PlayerComponent(
      position: Vector2(180, arena.groundY - 26),
      movementBounds: arena.playableBounds,
    );
    world.add(player);
    replayRecorder = DebugReplayRecorder(
      seed: debugSeed,
      ruleset: 'dnd2024',
      heroName: player.stats.name,
      bossId: 'training_golem',
    );

    // 3. Enemy Dummy / Vanguard (Placed on right lower platform)
    enemy = DummyEnemyComponent(
      position: Vector2(arena.size.x - 200, arena.size.y - 155 - 26),
      onTapped: () {
        if (currentPhase == GamePhase.planning) {
          queueAttackOnEnemy();
        }
      },
    );
    world.add(enemy);

    // 4. Ghost Preview Component for Tactical Mode
    ghostPreview = GhostPreviewComponent(player: player, queue: actionQueue);
    world.add(ghostPreview);

    lightingController = LightingController(
      target: player,
      visibleTargets: [enemy],
      worldSize: arena.size,
      darkvisionRadius: player.stats.darkvisionRadius,
      darknessIntensity: player.stats.config.vision.darknessIntensity,
    );
    world.add(lightingController);

    developerModeController = DeveloperModeController();
    world.add(
      DeveloperVisualizationComponent(
        player: player,
        enemy: enemy,
        mode: developerModeController,
      ),
    );

    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = player.position.clone();
    cameraFollowController = CameraFollowController(
      camera: camera,
      target: player,
      worldSize: arena.size,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (debugHudEnabled) debugTickNotifier.value++;
    actionCooldowns.update(dt);
    cameraFollowController.update();
    _checkCombatOutcome();
  }

  void _checkCombatOutcome() {
    if (combatOutcomeNotifier.value != null) return;
    CombatOutcome? outcome;
    if (enemy.stats.isDead) {
      outcome = CombatOutcome.victory;
    } else if (player.stats.isDead) {
      outcome = CombatOutcome.defeat;
    }
    if (outcome == null) return;

    combatOutcomeNotifier.value = outcome;
    phaseNotifier.value = GamePhase.cooldown;
    player.velocity = Vector2.zero();
    overlays.remove('actionBar');
    overlays.add('combatOutcome');
    CombatLogger.instance.logPhaseChange(
      fromPhase: currentPhase.name.toUpperCase(),
      toPhase: outcome == CombatOutcome.victory ? 'VICTORY' : 'DEFEAT',
    );
    if (outcome == CombatOutcome.victory) {
      platformServices.unlockAchievement('training_golem_defeated');
    }
    replayRecorder.complete(
      outcome == CombatOutcome.victory ? 'victory' : 'defeat',
    );
    platformServices.syncCombatStatistics(
      CombatStatistics(
        runId: DateTime.now().microsecondsSinceEpoch.toString(),
        completedAt: DateTime.now(),
        heroName: player.stats.name,
        bossId: 'training_golem',
        outcome: outcome == CombatOutcome.victory ? 'victory' : 'defeat',
        durationMs: DateTime.now().difference(combatStartedAt).inMilliseconds,
      ),
    );
  }

  void restartCombat() {
    combatOutcomeNotifier.value = null;
    combatStartedAt = DateTime.now();
    Dice.configureSeed(debugSeed);
    replayRecorder = DebugReplayRecorder(
      seed: debugSeed,
      ruleset: 'dnd2024',
      heroName: player.stats.name,
      bossId: 'training_golem',
    );
    phaseNotifier.value = GamePhase.realtime;
    actionQueue.clear();
    player.stats.currentHp = player.stats.maxHp;
    enemy.stats.currentHp = enemy.stats.maxHp;
    player.position.setValues(180, arena.groundY - 26);
    enemy.position.setValues(arena.size.x - 200, arena.size.y - 155 - 26);
    overlays.remove('combatOutcome');
  }

  void toggleDarkness() {
    lightingController.setDarkness(!lightingController.darknessActive);
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
    for (final action in actionQueue.actions) {
      replayRecorder.recordAction(action);
    }
  }

  /// Runs a fixed, non-reactive combat pipeline and plays it through the game.
  void startAutoCombat() {
    if (currentPhase != GamePhase.realtime || enemy.stats.isDead) return;

    final target = enemy.position.clone();
    final pipeline = <GameAction>[];
    if (player.position.distanceTo(target) >
        player.stats.meleeRange) {
      pipeline.add(DashAction(targetPosition: target.clone()));
    }
    pipeline.addAll([
      SlashAction(targetPosition: target.clone()),
      SlashAction(targetPosition: target.clone()),
      SlashAction(targetPosition: target.clone()),
    ]);

    phaseNotifier.value = GamePhase.executing;
    CombatLogger.instance.logTacticalAction(
      eventType: 'AUTO_PIPELINE_STARTED',
      action: pipeline.first,
      spentAP: 0,
      remainingAP: 0,
    );
    player.executePlan(
      pipeline,
      () => phaseNotifier.value = GamePhase.realtime,
    );
    for (final action in pipeline) {
      replayRecorder.recordAction(action);
    }
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
    lightingController.darkvisionRadius = newStats.darkvisionRadius;
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

  void triggerSlashHotkey() {
    if (currentPhase == GamePhase.planning) {
      selectedActionNotifier.value = ActionType.slash;
      return;
    }
    if (currentPhase != GamePhase.realtime) return;

    final slash = SlashAction(targetPosition: enemy.position.clone());
    if (!actionCooldowns.canUse(slash)) return;

    if (player.position.distanceTo(enemy.position) >
        player.stats.meleeRange) {
      CombatLogger.instance.logWarning(
        'COMBAT',
        'Slash hotkey pressed while the training golem is out of range.',
      );
      return;
    }

    actionCooldowns.start(slash, player.stats.config.cooldowns.slashCooldown);
    phaseNotifier.value = GamePhase.executing;
    replayRecorder.recordAction(slash);
    player.executePlan([slash], () => phaseNotifier.value = GamePhase.realtime);
  }

  void triggerSpellHotkey() {
    if (currentPhase != GamePhase.realtime) return;
    final spell = SpellAction(targetPosition: enemy.position.clone());
    if (!actionCooldowns.canUse(spell)) return;
    if (player.position.distanceTo(enemy.position) >
        player.stats.config.combat.spellRange) {
      CombatLogger.instance.logWarning(
        'SPELL',
        'Spell hotkey pressed while the training golem is out of range.',
      );
      return;
    }
    actionCooldowns.start(spell, player.stats.config.cooldowns.actionCooldown);
    phaseNotifier.value = GamePhase.executing;
    replayRecorder.recordAction(spell);
    player.executePlan([spell], () => phaseNotifier.value = GamePhase.realtime);
  }

  void cycleCombatMode() {
    const modes = [ActionType.slash, ActionType.ranged, ActionType.spell];
    final currentIndex = modes.indexOf(selectedActionNotifier.value);
    selectedActionNotifier.value = modes[(currentIndex + 1) % modes.length];
  }

  void queueActionAt(Vector2 tapPosition) {
    if (currentPhase != GamePhase.planning) return;

    final actionType = selectedActionNotifier.value;
    if (actionType == ActionType.move) {
      CombatLogger.instance.logWarning(
        'TACTICAL',
        'Pointer targeting is reserved for ability locations; movement uses keyboard input.',
      );
      return;
    }

    final GameAction action;
    switch (actionType) {
      case ActionType.move:
        action = MoveAction(targetPosition: tapPosition);
        break;
      case ActionType.slash:
        action = SlashAction(targetPosition: tapPosition);
        break;
      case ActionType.spell:
        action = SpellAction(targetPosition: tapPosition);
        break;
      case ActionType.ranged:
        action = RangedAction(targetPosition: tapPosition);
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

  /// Select an ability target while Tactical Pause is active.
  void selectAbilityTargetAt(Vector2 targetPosition) {
    if (currentPhase != GamePhase.planning) return;
    queueActionAt(targetPosition);
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

    if (currentPhase == GamePhase.planning) {
      final worldPos = camera.globalToLocal(event.localPosition);
      selectAbilityTargetAt(worldPos);
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

    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f3) {
      developerModeController.toggle();
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyF) {
      startAutoCombat();
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyC) {
      triggerSpellHotkey();
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyL) {
      toggleDarkness();
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab) {
      cycleCombatMode();
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

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyE ||
          event.logicalKey == LogicalKeyboardKey.altGraph) {
        triggerSlashHotkey();
        return KeyEventResult.handled;
      }
      if (currentPhase == GamePhase.planning &&
          (event.logicalKey == LogicalKeyboardKey.keyQ ||
              event.logicalKey == LogicalKeyboardKey.controlRight)) {
        selectedActionNotifier.value = ActionType.dash;
        return KeyEventResult.handled;
      }
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

    // 2. SPACE always belongs to jumping; Enter controls Tactical Pause.
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
      if (currentPhase == GamePhase.realtime) {
        player.jump();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
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
      // Drop down through a platform on tap of S / Down arrow while grounded
      if (event is KeyDownEvent &&
          (event.logicalKey == LogicalKeyboardKey.keyS ||
              event.logicalKey == LogicalKeyboardKey.arrowDown)) {
        player.dropDown();
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

      // Vertical flight (W / S / Up / Down); SPACE remains the only jump trigger.
      double verticalInput = 0.0;
      if (keysPressed.contains(LogicalKeyboardKey.keyW) ||
          keysPressed.contains(LogicalKeyboardKey.arrowUp)) {
        verticalInput -= 1.0;
      }
      if (keysPressed.contains(LogicalKeyboardKey.keyS) ||
          keysPressed.contains(LogicalKeyboardKey.arrowDown)) {
        verticalInput += 1.0;
      }
      player.verticalFlightInput = verticalInput;
    }

    return KeyEventResult.ignored;
  }
}
