import 'package:flutter_test/flutter_test.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:builds_and_bosses_flame/game/combat_coordinator.dart';
import 'package:builds_and_bosses_flame/game/components/player_component.dart';
import 'package:builds_and_bosses_flame/game/components/dummy_enemy_component.dart';
import 'package:builds_and_bosses_flame/game/combat_completion.dart';
import 'package:builds_and_bosses_flame/game/game_phase.dart';
import 'package:builds_and_bosses_flame/core/actions/game_action.dart';
import 'package:builds_and_bosses_flame/core/combat/combat_timer_controller.dart';
import 'package:builds_and_bosses_flame/platform/local_platform_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CombatCoordinator Unit Tests', () {
    late PlayerComponent player;
    late DummyEnemyComponent enemy;
    late ValueNotifier<GamePhase> phaseNotifier;
    late CombatTimerController timerController;
    late List<String> activeOverlays;
    late CombatCoordinator coordinator;

    setUp(() {
      player = PlayerComponent(
        position: Vector2(100, 200),
        movementBounds: Rect.fromLTWH(0, 0, 1000, 500),
      );
      enemy = DummyEnemyComponent(position: Vector2(400, 200));
      phaseNotifier = ValueNotifier<GamePhase>(GamePhase.realtime);
      timerController = CombatTimerController();
      activeOverlays = [];

      coordinator = CombatCoordinator(
        context: CombatCoordinatorContext(
          player: player,
          enemy: enemy,
          phaseNotifier: phaseNotifier,
          timerController: timerController,
          completion: CombatCompletion(LocalPlatformServices()),
          onAddOverlay: (o) => activeOverlays.add(o),
          onRemoveOverlay: (o) => activeOverlays.remove(o),
        ),
        playerResetPosition: Vector2(100, 200),
        enemyResetPosition: Vector2(400, 200),
        debugSeed: 42,
      );
    });

    test('Initializes with default action queue and Slash selected', () {
      expect(coordinator.actionQueue.isEmpty, isTrue);
      expect(
        coordinator.selectedActionNotifier.value,
        equals(ActionType.slash),
      );
      expect(coordinator.combatOutcomeNotifier.value, isNull);
    });

    test(
      'startPlanning transitions to planning phase and adds actionBar overlay',
      () {
        coordinator.startPlanning();
        expect(phaseNotifier.value, equals(GamePhase.planning));
        expect(activeOverlays, contains('actionBar'));
        expect(
          coordinator.selectedActionNotifier.value,
          equals(ActionType.slash),
        );
      },
    );

    test(
      'cancelPlanning returns to realtime and removes actionBar overlay',
      () {
        coordinator.startPlanning();
        coordinator.cancelPlanning();
        expect(phaseNotifier.value, equals(GamePhase.realtime));
        expect(activeOverlays, isNot(contains('actionBar')));
      },
    );

    test('queueAttackOnEnemy queues Slash action targeting enemy in planning phase', () {
      coordinator.startPlanning();
      coordinator.queueAttackOnEnemy();

      expect(coordinator.actionQueue.count, equals(1));
      final queued = coordinator.actionQueue.actions.first as SlashAction;
      expect(queued.targetPosition.x, closeTo(enemy.position.x, 0.01));
      expect(queued.targetPosition.y, closeTo(enemy.position.y, 0.01));
    });

    test('queueActionAt queues selected action within AP budget', () {
      coordinator.startPlanning();
      coordinator.queueActionAt(Vector2(150, 150));

      expect(coordinator.actionQueue.count, equals(1));
      expect(coordinator.actionQueue.spentAP, equals(25));

      coordinator.undoLastAction();
      expect(coordinator.actionQueue.count, equals(0));
      expect(coordinator.actionQueue.spentAP, equals(0));
    });

    test('cycleCombatMode cycles through slash -> ranged -> spell', () {
      expect(
        coordinator.selectedActionNotifier.value,
        equals(ActionType.slash),
      );
      coordinator.cycleCombatMode();
      expect(
        coordinator.selectedActionNotifier.value,
        equals(ActionType.ranged),
      );
      coordinator.cycleCombatMode();
      expect(
        coordinator.selectedActionNotifier.value,
        equals(ActionType.spell),
      );
      coordinator.cycleCombatMode();
      expect(
        coordinator.selectedActionNotifier.value,
        equals(ActionType.slash),
      );
    });

    test('restartCombat restores player and enemy states', () {
      player.position.setValues(999, 999);
      enemy.position.setValues(888, 888);
      coordinator.startPlanning();

      coordinator.restartCombat();
      expect(phaseNotifier.value, equals(GamePhase.realtime));
      expect(coordinator.actionQueue.isEmpty, isTrue);
      expect(player.position.x, equals(100));
      expect(player.position.y, equals(200));
      expect(enemy.position.x, equals(400));
      expect(enemy.position.y, equals(200));
    });
  });
}
