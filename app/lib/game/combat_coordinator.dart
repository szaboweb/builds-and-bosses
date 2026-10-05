import 'dart:async';

import 'package:flame/extensions.dart';
import 'package:flutter/foundation.dart';

import '../core/actions/action_cooldowns.dart';
import '../core/actions/action_queue.dart';
import '../core/actions/game_action.dart';
import '../core/combat/combat_logger.dart';
import '../core/combat/combat_timer_controller.dart';
import '../core/debug/debug_replay.dart';
import '../core/dnd/dice.dart';
import '../core/platform/platform_services.dart';
import 'combat_completion.dart';
import 'combat_coordinator_context.dart';
import 'components/dummy_enemy_component.dart';
import 'components/player_component.dart';
import 'game_phase.dart';

export 'combat_coordinator_context.dart';

enum CombatOutcome { victory, defeat }

/// Coordinates combat execution, target selection, action queueing,
/// cooldown tracking, hotkey actions, and victory/defeat resolution.
class CombatCoordinator {
  final CombatCoordinatorContext context;
  final Vector2 playerResetPosition;
  final Vector2 enemyResetPosition;
  final int debugSeed;

  PlayerComponent get player => context.player;
  DummyEnemyComponent get enemy => context.enemy;
  ValueNotifier<GamePhase> get phaseNotifier => context.phaseNotifier;
  CombatTimerController get timerController => context.timerController;
  CombatCompletion get completion => context.completion;
  void Function(String overlay) get onAddOverlay => context.onAddOverlay;
  void Function(String overlay) get onRemoveOverlay => context.onRemoveOverlay;

  final ActionQueue actionQueue;
  final ActionCooldowns actionCooldowns = ActionCooldowns();
  final ValueNotifier<ActionType> selectedActionNotifier =
      ValueNotifier<ActionType>(ActionType.slash);
  final ValueNotifier<CombatOutcome?> combatOutcomeNotifier =
      ValueNotifier<CombatOutcome?>(null);
  late DebugReplayRecorder replayRecorder;

  CombatCoordinator({
    required this.context,
    required this.playerResetPosition,
    required this.enemyResetPosition,
    required this.debugSeed,
    ActionQueue? actionQueue,
  }) : actionQueue = actionQueue ?? ActionQueue(maxAP: 100) {
    _initReplayRecorder();
  }

  void _initReplayRecorder() {
    replayRecorder = DebugReplayRecorder(
      seed: debugSeed,
      ruleset: 'dnd2024',
      heroName: player.stats.name,
      bossId: 'training_golem',
    );
  }

  void update(double dt) {
    actionCooldowns.update(dt);
    _checkCombatOutcome();
  }

  void startPlanning() {
    if (phaseNotifier.value != GamePhase.realtime) return;
    timerController.pause();
    phaseNotifier.value = GamePhase.planning;
    player.velocity = Vector2.zero();
    actionQueue.clear();
    selectedActionNotifier.value = ActionType.slash;
    onAddOverlay('actionBar');
    CombatLogger.instance.logPhaseChange(
      fromPhase: 'REALTIME',
      toPhase: 'PLANNING',
    );
  }

  void cancelPlanning() {
    if (phaseNotifier.value != GamePhase.planning) return;
    actionQueue.clear();
    phaseNotifier.value = GamePhase.realtime;
    timerController.resume();
    onRemoveOverlay('actionBar');
    CombatLogger.instance.logPhaseChange(
      fromPhase: 'PLANNING',
      toPhase: 'REALTIME',
    );
  }

  void executePlan() {
    if (phaseNotifier.value != GamePhase.planning) return;
    if (actionQueue.isEmpty) {
      cancelPlanning();
      return;
    }

    phaseNotifier.value = GamePhase.executing;
    timerController.resume();
    onRemoveOverlay('actionBar');
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

  void startAutoCombat() {
    if (phaseNotifier.value != GamePhase.realtime || enemy.stats.isDead) return;

    final target = enemy.position.clone();
    final pipeline = <GameAction>[
      if (player.position.distanceTo(target) > player.stats.meleeRange)
        DashAction(targetPosition: target.clone()),
      SlashAction(targetPosition: target.clone()),
      SlashAction(targetPosition: target.clone()),
      SlashAction(targetPosition: target.clone()),
    ];

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

  void triggerSlashHotkey() {
    if (phaseNotifier.value == GamePhase.planning) {
      selectedActionNotifier.value = ActionType.slash;
      return;
    }
    if (phaseNotifier.value != GamePhase.realtime) return;

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
    _executeImmediateAction(slash);
  }

  void triggerSpellHotkey() {
    if (phaseNotifier.value != GamePhase.realtime) return;
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
    _executeImmediateAction(spell);
  }

  void triggerRangedHotkey() {
    if (phaseNotifier.value != GamePhase.realtime) return;
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
    _executeImmediateAction(ranged);
  }

  void _executeImmediateAction(GameAction action) {
    phaseNotifier.value = GamePhase.executing;
    replayRecorder.recordAction(action);
    player.executePlan([
      action,
    ], () => phaseNotifier.value = GamePhase.realtime);
  }

  void cycleCombatMode() {
    const modes = [ActionType.slash, ActionType.ranged, ActionType.spell];
    final currentIndex = modes.indexOf(selectedActionNotifier.value);
    selectedActionNotifier.value = modes[(currentIndex + 1) % modes.length];
  }

  void triggerSelectedCombatHotkey() {
    switch (selectedActionNotifier.value) {
      case ActionType.slash:
        triggerSlashHotkey();
      case ActionType.ranged:
        triggerRangedHotkey();
      case ActionType.spell:
        triggerSpellHotkey();
      case ActionType.move:
      case ActionType.dash:
      case ActionType.heal:
        break;
    }
  }

  void queueAttackOnEnemy() {
    if (phaseNotifier.value != GamePhase.planning) return;
    _tryAddAction(SlashAction(targetPosition: enemy.position.clone()));
  }

  void selectAbilityTargetAt(Vector2 targetPosition) =>
      queueActionAt(targetPosition);

  void queueActionAt(Vector2 tapPosition) {
    if (phaseNotifier.value != GamePhase.planning) return;
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

  void _checkCombatOutcome() {
    if (combatOutcomeNotifier.value != null) return;
    final outcome = enemy.stats.isDead
        ? CombatOutcome.victory
        : (player.stats.isDead ? CombatOutcome.defeat : null);
    if (outcome == null) return;

    combatOutcomeNotifier.value = outcome;
    phaseNotifier.value = GamePhase.cooldown;
    timerController.stop();
    player.velocity = Vector2.zero();
    onRemoveOverlay('actionBar');
    onAddOverlay('combatOutcome');
    CombatLogger.instance.logPhaseChange(
      fromPhase: phaseNotifier.value.name.toUpperCase(),
      toPhase: outcome == CombatOutcome.victory ? 'VICTORY' : 'DEFEAT',
    );
    player.cancelPlan();
    replayRecorder.complete(
      outcome == CombatOutcome.victory ? 'victory' : 'defeat',
    );
    unawaited(
      completion.record(
        CombatStatistics(
          runId: DateTime.now().microsecondsSinceEpoch.toString(),
          completedAt: DateTime.now(),
          heroName: player.stats.name,
          bossId: 'training_golem',
          outcome: outcome == CombatOutcome.victory ? 'victory' : 'defeat',
          durationMs: timerController.elapsed.inMilliseconds,
        ),
      ),
    );
  }

  void restartCombat() {
    player.cancelPlan();
    combatOutcomeNotifier.value = null;
    timerController.reset();
    Dice.configureSeed(debugSeed);
    _initReplayRecorder();
    phaseNotifier.value = GamePhase.realtime;
    actionQueue.clear();
    player.stats.currentHp = player.stats.maxHp;
    enemy.stats.currentHp = enemy.stats.maxHp;
    player.position.setFrom(playerResetPosition);
    enemy.position.setFrom(enemyResetPosition);
    onRemoveOverlay('combatOutcome');
  }
}
