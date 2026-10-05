import 'dart:async';

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
import '../core/combat/combat_timer_controller.dart';
import '../core/dnd/character_stats.dart';
import '../core/dnd/dice.dart';
import '../core/debug/debug_replay.dart';
import '../core/platform/platform_services.dart';
import '../platform/local_platform_services.dart';
import '../core/arena/arena_layout_blueprint.dart';
import 'components/arena_editor_component.dart';
import 'components/arena_map_component.dart';
import 'components/dummy_enemy_component.dart';
import 'components/ghost_preview_component.dart';
import 'components/player_component.dart';
import 'editor/arena_editor_controller.dart';
import 'camera_follow_controller.dart';
import 'lighting_controller.dart';
import 'developer_mode_controller.dart';
import 'developer_visualization_component.dart';
import 'combat_completion.dart';
import 'game_input_controller.dart';
import 'game_phase.dart';

export 'game_phase.dart';

enum CombatOutcome { victory, defeat }

/// The main Flame game instance integrating the Side-view Platformer arena,
/// gravity physics, player jumping, enemy dummy, and Tactical Mode planning loop.
class TacticalModeGame extends FlameGame
    with KeyboardEvents, TapCallbacks
    implements GameInputTarget {
  final PlatformServices platformServices;
  final int debugSeed;

  /// Fixed logical canvas (16:9), scaled 2x at 1280x720 and 3x at 1920x1080.
  static const double logicalWidth = 640;
  static const double logicalHeight = 360;

  TacticalModeGame({PlatformServices? platformServices, int? debugSeed})
    : platformServices = platformServices ?? LocalPlatformServices(),
      debugSeed = debugSeed ?? DateTime.now().millisecondsSinceEpoch,
      super(
        camera: CameraComponent.withFixedResolution(
          width: logicalWidth,
          height: logicalHeight,
        ),
      );

  late ArenaMapComponent arena;
  late PlayerComponent player;
  late DummyEnemyComponent enemy;
  late GhostPreviewComponent ghostPreview;
  late CameraFollowController cameraFollowController;
  late LightingController lightingController;
  late DeveloperModeController developerModeController;
  late DebugReplayRecorder replayRecorder;
  late final CombatCompletion combatCompletion = CombatCompletion(
    platformServices,
  );
  late final GameInputController inputController = GameInputController(
    target: this,
  );
  late final ArenaEditorController editorController = ArenaEditorController(
    blueprint: ArenaLayoutBlueprint.defaultArena(),
  );
  late ArenaEditorComponent editorComponent;

  @override
  bool get isCharacterBuilderActive => overlays.isActive('characterBuilder');

  @override
  bool get isLevelEditorActive => overlays.isActive('levelEditor');

  @override
  void toggleDeveloperMode() => developerModeController.toggle();

  @override
  void selectAction(ActionType action) => selectedActionNotifier.value = action;

  @override
  void jump() => player.jump();

  @override
  void dropDown() => player.dropDown();

  @override
  void setHorizontalInput(double input) => player.velocity.x = input;

  @override
  void setVerticalFlightInput(double input) =>
      player.verticalFlightInput = input;

  final ActionQueue actionQueue = ActionQueue(maxAP: 100);
  final ActionCooldowns actionCooldowns = ActionCooldowns();
  final CombatTimerController combatTimerController = CombatTimerController();
  final ValueNotifier<int> debugTickNotifier = ValueNotifier<int>(0);
  ValueNotifier<Duration> get combatTimerNotifier =>
      combatTimerController.elapsedNotifier;
  bool get debugHudEnabled => developerModeController.enabled.value;

  // Observable state for Flutter UI widgets
  final ValueNotifier<GamePhase> phaseNotifier = ValueNotifier<GamePhase>(
    GamePhase.realtime,
  );
  final ValueNotifier<CombatOutcome?> combatOutcomeNotifier =
      ValueNotifier<CombatOutcome?>(null);
  final ValueNotifier<ActionType> selectedActionNotifier =
      ValueNotifier<ActionType>(ActionType.slash);
  static const List<ActionType?> hotbarSlots = [
    ActionType.slash,
    ActionType.ranged,
    ActionType.spell,
    ActionType.dash,
    ActionType.heal,
    null,
    null,
    null,
    null,
    null,
  ];
  CampaignBlueprint? activeBlueprint;

  @override
  GamePhase get currentPhase => phaseNotifier.value;

  @override
  void selectHotbarSlot(int index) {
    if (index < 0 || index >= hotbarSlots.length) return;
    final action = hotbarSlots[index];
    if (action != null) selectedActionNotifier.value = action;
  }

  @override
  Color backgroundColor() => const Color(0xFF0D0B14);

  @override
  Future<void> onLoad() async {
    super.onLoad();
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

    editorComponent = ArenaEditorComponent(
      controller: editorController,
      arenaSize: arena.size,
    );
    world.add(editorComponent);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (currentPhase != GamePhase.planning &&
        combatOutcomeNotifier.value == null) {
      combatTimerController.update(dt);
    }
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
    combatTimerController.stop();
    player.velocity = Vector2.zero();
    overlays.remove('actionBar');
    overlays.add('combatOutcome');
    CombatLogger.instance.logPhaseChange(
      fromPhase: currentPhase.name.toUpperCase(),
      toPhase: outcome == CombatOutcome.victory ? 'VICTORY' : 'DEFEAT',
    );
    player.cancelPlan();
    replayRecorder.complete(
      outcome == CombatOutcome.victory ? 'victory' : 'defeat',
    );
    unawaited(
      combatCompletion.record(
        CombatStatistics(
          runId: DateTime.now().microsecondsSinceEpoch.toString(),
          completedAt: DateTime.now(),
          heroName: player.stats.name,
          bossId: 'training_golem',
          outcome: outcome == CombatOutcome.victory ? 'victory' : 'defeat',
          durationMs: combatTimerController.elapsed.inMilliseconds,
        ),
      ),
    );
  }

  void restartCombat() {
    player.cancelPlan();
    combatOutcomeNotifier.value = null;
    combatTimerController.reset();
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

  @override
  void toggleDarkness() {
    lightingController.setDarkness(!lightingController.darknessActive);
  }

  // --- Phase Controls ---

  @override
  void startPlanning() {
    if (currentPhase != GamePhase.realtime) return;
    combatTimerController.pause();
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

  @override
  void cancelPlanning() {
    if (currentPhase != GamePhase.planning) return;
    actionQueue.clear();
    phaseNotifier.value = GamePhase.realtime;
    combatTimerController.resume();
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
    combatTimerController.resume();
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
  @override
  void startAutoCombat() {
    if (currentPhase != GamePhase.realtime || enemy.stats.isDead) return;

    final target = enemy.position.clone();
    final pipeline = <GameAction>[];
    if (player.position.distanceTo(target) > player.stats.meleeRange) {
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

  @override
  void openCharacterBuilder() {
    player.velocity = Vector2.zero();
    overlays.add('characterBuilder');
    CombatLogger.instance.logPhaseChange(
      fromPhase: currentPhase.name.toUpperCase(),
      toPhase: 'BUILDER',
    );
  }

  @override
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
    actionQueue.setMaxAP(newStats.maxMana);
    lightingController.darkvisionRadius = newStats.darkvisionRadius;
    activeBlueprint = blueprint;
    CombatLogger.instance.logBuildChange(
      oldStats: oldStats,
      newStats: newStats,
    );
    closeCharacterBuilder();
  }

  // --- Level Editor Controls ---

  @override
  void openLevelEditor() {
    if (isLoaded) player.velocity = Vector2.zero();
    editorController.isEnabled = true;
    overlays.add('levelEditor');
    CombatLogger.instance.logPhaseChange(
      fromPhase: currentPhase.name.toUpperCase(),
      toPhase: 'EDITOR',
    );
  }

  @override
  void closeLevelEditor() {
    editorController.isEnabled = false;
    overlays.remove('levelEditor');
    if (isLoaded) applyArenaBlueprint(editorController.blueprint);
    CombatLogger.instance.logPhaseChange(
      fromPhase: 'EDITOR',
      toPhase: currentPhase.name.toUpperCase(),
    );
  }

  @override
  void toggleLevelEditor() =>
      isLevelEditorActive ? closeLevelEditor() : openLevelEditor();

  void applyArenaBlueprint(ArenaLayoutBlueprint blueprint) {
    if (!isLoaded) return;
    arena.applyBlueprint(blueprint);
    player.position.setValues(
      blueprint.playerSpawnX,
      blueprint.playerSpawnY - 26,
    );
    player.velocity.setZero();
    final dummy = blueprint.spawns
        .where((s) => s.type == 'training_dummy')
        .firstOrNull;
    if (dummy != null) {
      enemy.position.setValues(dummy.x, dummy.y - 26);
    }
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

    if (!player.canReachMelee(enemy.position)) {
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
    final spell = SpellAction(
      targetPosition: enemy.position.clone(),
      knockback: player.stats.config.combat.spellKnockback,
    );
    if (!actionCooldowns.canUse(spell)) return;
    if (player.position.distanceTo(enemy.position) > player.stats.spellRange) {
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

  void triggerRangedHotkey() {
    if (currentPhase != GamePhase.realtime) return;
    final ranged = RangedAction(targetPosition: enemy.position.clone());
    if (!actionCooldowns.canUse(ranged)) return;
    if (player.position.distanceTo(enemy.position) >
        player.stats.rangedLongRange) {
      CombatLogger.instance.logWarning(
        'RANGED',
        'Ranged hotkey pressed while the training golem is out of range.',
      );
      return;
    }
    actionCooldowns.start(ranged, player.stats.config.cooldowns.actionCooldown);
    phaseNotifier.value = GamePhase.executing;
    replayRecorder.recordAction(ranged);
    player.executePlan([
      ranged,
    ], () => phaseNotifier.value = GamePhase.realtime);
  }

  @override
  void cycleCombatMode() {
    const modes = [ActionType.slash, ActionType.ranged, ActionType.spell];
    final currentIndex = modes.indexOf(selectedActionNotifier.value);
    selectedActionNotifier.value = modes[(currentIndex + 1) % modes.length];
  }

  @override
  void triggerSelectedCombatHotkey() {
    switch (selectedActionNotifier.value) {
      case ActionType.slash:
        triggerSlashHotkey();
        break;
      case ActionType.ranged:
        triggerRangedHotkey();
        break;
      case ActionType.spell:
        triggerSpellHotkey();
        break;
      case ActionType.move:
      case ActionType.dash:
      case ActionType.heal:
        break;
    }
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

    final action = switch (actionType) {
      ActionType.move => MoveAction(targetPosition: tapPosition),
      ActionType.slash => SlashAction(targetPosition: tapPosition),
      ActionType.spell => SpellAction(
        targetPosition: tapPosition,
        knockback: player.stats.config.combat.spellKnockback,
      ),
      ActionType.ranged => RangedAction(targetPosition: tapPosition),
      ActionType.dash => DashAction(targetPosition: tapPosition),
      ActionType.heal => HealAction(),
    };
    _tryAddAction(action);
  }

  /// Select an ability target while Tactical Pause is active.
  @override
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
    inputController.handleTapDown(event.localPosition, camera.globalToLocal);
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    return inputController.handleKeyEvent(event, keysPressed);
  }
}
