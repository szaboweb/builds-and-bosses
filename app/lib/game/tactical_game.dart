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
import 'combat_coordinator.dart';
import 'combat_completion.dart';
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
import 'game_input_controller.dart';
import 'game_phase.dart';

export 'combat_coordinator.dart';
export 'game_phase.dart';

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
  late ArenaLayoutBlueprint currentArenaBlueprint;
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
  late final CombatCoordinator combatCoordinator;

  @override
  bool get isCharacterBuilderActive => overlays.isActive('characterBuilder');
  @override
  bool get isLevelEditorActive => overlays.isActive('levelEditor');
  @override
  void toggleDeveloperMode() => developerModeController.toggle();
  @override
  void selectAction(ActionType action) =>
      combatCoordinator.selectedActionNotifier.value = action;
  @override
  void jump() => player.jump();
  @override
  void dropDown() => player.dropDown();
  @override
  void setHorizontalInput(double input) => player.velocity.x = input;
  @override
  void setVerticalFlightInput(double input) =>
      player.verticalFlightInput = input;

  final CombatTimerController combatTimerController = CombatTimerController();
  final ValueNotifier<int> debugTickNotifier = ValueNotifier<int>(0);
  ValueNotifier<Duration> get combatTimerNotifier =>
      combatTimerController.elapsedNotifier;
  bool get debugHudEnabled => developerModeController.enabled.value;

  final ValueNotifier<GamePhase> phaseNotifier = ValueNotifier<GamePhase>(
    GamePhase.realtime,
  );

  // Delegated combat coordinator state
  ActionQueue get actionQueue => combatCoordinator.actionQueue;
  ActionCooldowns get actionCooldowns => combatCoordinator.actionCooldowns;
  ValueNotifier<CombatOutcome?> get combatOutcomeNotifier =>
      combatCoordinator.combatOutcomeNotifier;
  ValueNotifier<ActionType> get selectedActionNotifier =>
      combatCoordinator.selectedActionNotifier;
  DebugReplayRecorder get replayRecorder => combatCoordinator.replayRecorder;

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
    if (action != null) selectAction(action);
  }

  @override
  Color backgroundColor() => const Color(0xFF0D0B14);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    Dice.configureSeed(debugSeed);

    // Initialize with default arena first
    currentArenaBlueprint = ArenaLayoutBlueprint.defaultArena();

    _initializeGameComponents();
    _initializeControllers();
    _buildWorldComponents();

    // Show level selector after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      _showLevelSelector();
    });
  }

  void _initializeGameComponents() {
    arena = ArenaMapComponent(
      arenaWidth: currentArenaBlueprint.arenaWidth,
      arenaHeight: currentArenaBlueprint.arenaHeight,
    );
    player = PlayerComponent(
      position: Vector2(currentArenaBlueprint.playerSpawnX, arena.groundY - 26),
      movementBounds: arena.playableBounds,
    );
    enemy = DummyEnemyComponent(
      position: Vector2(arena.size.x - 200, arena.size.y - 155 - 26),
      onTapped: () {
        if (currentPhase == GamePhase.planning) queueAttackOnEnemy();
      },
    );
  }

  void _initializeControllers() {
    final playerSpawnPos = Vector2(
      currentArenaBlueprint.playerSpawnX,
      arena.groundY - 26,
    );
    final enemySpawnPos = Vector2(arena.size.x - 200, arena.size.y - 155 - 26);

    combatCoordinator = CombatCoordinator(
      context: CombatCoordinatorContext(
        player: player,
        enemy: enemy,
        phaseNotifier: phaseNotifier,
        timerController: combatTimerController,
        completion: combatCompletion,
        onAddOverlay: overlays.add,
        onRemoveOverlay: overlays.remove,
      ),
      playerResetPosition: playerSpawnPos,
      enemyResetPosition: enemySpawnPos,
      debugSeed: debugSeed,
    );
    ghostPreview = GhostPreviewComponent(player: player, queue: actionQueue);
    lightingController = LightingController(
      target: player,
      visibleTargets: [enemy],
      worldSize: arena.size,
      darkvisionRadius: player.stats.darkvisionRadius,
      darknessIntensity: player.stats.config.vision.darknessIntensity,
    );
    developerModeController = DeveloperModeController();
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
  }

  void _buildWorldComponents() {
    world.addAll([
      arena,
      player,
      enemy,
      ghostPreview,
      lightingController,
      DeveloperVisualizationComponent(
        player: player,
        enemy: enemy,
        mode: developerModeController,
      ),
      editorComponent,
    ]);
  }

  /// Shows the level selector overlay for the user to choose a level.
  void _showLevelSelector() {
    overlays.add('levelSelector');
  }

  /// Loads a specific arena layout into the game world.
  void loadLevel(ArenaLayoutBlueprint blueprint) {
    currentArenaBlueprint = blueprint;

    // Update arena dimensions and apply blueprint
    arena.size = Vector2(blueprint.arenaWidth, blueprint.arenaHeight);
    arena.applyBlueprint(blueprint);

    // Reset player position to blueprint spawn point
    final playerSpawnPos = Vector2(blueprint.playerSpawnX, arena.groundY - 26);
    player.position = playerSpawnPos;

    // Update camera position
    camera.viewfinder.position = playerSpawnPos.clone();

    // Close the level selector overlay
    overlays.remove('levelSelector');
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (currentPhase != GamePhase.planning &&
        combatOutcomeNotifier.value == null) {
      combatTimerController.update(dt);
    }
    if (debugHudEnabled) debugTickNotifier.value++;
    combatCoordinator.update(dt);
    cameraFollowController.update();
  }

  void restartCombat() => combatCoordinator.restartCombat();

  @override
  void toggleDarkness() {
    lightingController.setDarkness(!lightingController.darknessActive);
  }

  // --- Phase Controls ---

  @override
  void startPlanning() => combatCoordinator.startPlanning();
  @override
  void cancelPlanning() => combatCoordinator.cancelPlanning();
  void executePlan() => combatCoordinator.executePlan();
  @override
  void startAutoCombat() => combatCoordinator.startAutoCombat();

  // --- Character Builder Controls ---

  @override
  void openCharacterBuilder() {
    player.velocity = Vector2.zero();
    overlays.add('characterBuilder');
    _logPhase('BUILDER');
  }

  @override
  void closeCharacterBuilder() {
    overlays.remove('characterBuilder');
    _logPhase(currentPhase.name.toUpperCase());
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
    _logPhase('EDITOR');
  }

  @override
  void closeLevelEditor() {
    editorController.isEnabled = false;
    overlays.remove('levelEditor');
    if (isLoaded) applyArenaBlueprint(editorController.blueprint);
    _logPhase(currentPhase.name.toUpperCase());
  }

  @override
  void toggleLevelEditor() =>
      isLevelEditorActive ? closeLevelEditor() : openLevelEditor();

  void _logPhase(String to) => CombatLogger.instance.logPhaseChange(
    fromPhase: currentPhase.name.toUpperCase(),
    toPhase: to,
  );

  void applyArenaBlueprint(ArenaLayoutBlueprint blueprint) {
    if (!isLoaded) return;
    arena.applyBlueprint(blueprint);
    final spawnPos = Vector2(
      blueprint.playerSpawnX,
      blueprint.playerSpawnY - 26,
    );
    player.position.setFrom(spawnPos);
    combatCoordinator.playerResetPosition.setFrom(spawnPos);
    player.velocity.setZero();
    final dummy = blueprint.spawns
        .where((s) => s.type == 'training_dummy')
        .firstOrNull;
    if (dummy != null) {
      final dummyPos = Vector2(dummy.x, dummy.y - 26);
      enemy.position.setFrom(dummyPos);
      combatCoordinator.enemyResetPosition.setFrom(dummyPos);
    }
  }

  // --- Action Queueing & Hotkeys (Delegated to CombatCoordinator) ---

  void queueAttackOnEnemy() => combatCoordinator.queueAttackOnEnemy();
  void triggerSlashHotkey() => combatCoordinator.triggerSlashHotkey();
  void triggerSpellHotkey() => combatCoordinator.triggerSpellHotkey();
  void triggerRangedHotkey() => combatCoordinator.triggerRangedHotkey();
  @override
  void cycleCombatMode() => combatCoordinator.cycleCombatMode();
  @override
  void triggerSelectedCombatHotkey() =>
      combatCoordinator.triggerSelectedCombatHotkey();
  void queueActionAt(Vector2 tapPosition) =>
      combatCoordinator.queueActionAt(tapPosition);
  @override
  void selectAbilityTargetAt(Vector2 targetPosition) =>
      combatCoordinator.selectAbilityTargetAt(targetPosition);
  void undoLastAction() => combatCoordinator.undoLastAction();

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
