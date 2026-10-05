import 'package:flutter/foundation.dart';

import '../core/combat/combat_timer_controller.dart';
import 'combat_completion.dart';
import 'components/dummy_enemy_component.dart';
import 'components/player_component.dart';
import 'game_phase.dart';

/// Bundles component and controller references required by CombatCoordinator.
class CombatCoordinatorContext {
  final PlayerComponent player;
  final DummyEnemyComponent enemy;
  final ValueNotifier<GamePhase> phaseNotifier;
  final CombatTimerController timerController;
  final CombatCompletion completion;
  final void Function(String overlay) onAddOverlay;
  final void Function(String overlay) onRemoveOverlay;

  const CombatCoordinatorContext({
    required this.player,
    required this.enemy,
    required this.phaseNotifier,
    required this.timerController,
    required this.completion,
    required this.onAddOverlay,
    required this.onRemoveOverlay,
  });
}
