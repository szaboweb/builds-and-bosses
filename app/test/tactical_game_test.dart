import 'package:flutter_test/flutter_test.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:builds_and_bosses_flame/game/tactical_game.dart';
import 'package:builds_and_bosses_flame/core/actions/game_action.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tactical Mode Game State & Planning Loop Tests', () {
    late TacticalModeGame game;

    setUp(() async {
      game = TacticalModeGame();
      game.overlays.addEntry(
        'actionBar',
        (context, game) => const SizedBox.shrink(),
      );
      game.overlays.addEntry(
        'planningHud',
        (context, game) => const SizedBox.shrink(),
      );
      game.onGameResize(Vector2(960, 540));
      await game.onLoad();
    });

    test('Initializes in realtime phase with player on ground and enemy on platform', () {
      expect(game.currentPhase, equals(GamePhase.realtime));
      expect(game.actionQueue.isEmpty, isTrue);
      expect(game.player, isNotNull);
      expect(game.enemy, isNotNull);
      expect(game.ghostPreview, isNotNull);
      expect(game.arena.platforms.length, greaterThanOrEqualTo(3));
    });

    test('startPlanning transitions to planning phase and resets queue with Slash default', () {
      game.startPlanning();
      expect(game.currentPhase, equals(GamePhase.planning));
      expect(game.selectedActionNotifier.value, equals(ActionType.slash));
      expect(game.actionQueue.remainingAP, equals(100));
    });

    test('queueActionAt queues selected action within budget', () {
      game.startPlanning();

      // Default selected action is Slash (25 AP)
      game.queueActionAt(Vector2(150, 150));
      expect(game.actionQueue.count, equals(1));
      expect(game.actionQueue.actions.first, isA<SlashAction>());
      expect(game.actionQueue.spentAP, equals(25));

      // Pointer targeting does not create movement actions.
      game.selectedActionNotifier.value = ActionType.move;
      game.queueActionAt(Vector2(200, 200));
      expect(game.actionQueue.count, equals(1));
      expect(game.actionQueue.spentAP, equals(25));

      // Change action type to Dash (20 AP)
      game.selectedActionNotifier.value = ActionType.dash;
      game.queueActionAt(Vector2(250, 250));
      expect(game.actionQueue.count, equals(2));
      expect(game.actionQueue.actions.last, isA<DashAction>());
      expect(game.actionQueue.spentAP, equals(45));

      // Change action type to Heal (30 AP)
      game.selectedActionNotifier.value = ActionType.heal;
      game.queueActionAt(Vector2.zero());
      expect(game.actionQueue.count, equals(3));
      expect(game.actionQueue.actions.last, isA<HealAction>());
      expect(game.actionQueue.spentAP, equals(75));
    });

    test('Pointer input targets abilities only during Tactical Pause', () {
      game.player.velocity = Vector2.zero();
      game.selectAbilityTargetAt(Vector2(250, 180));

      expect(game.actionQueue.isEmpty, isTrue);
      expect(game.player.velocity, equals(Vector2.zero()));

      game.startPlanning();
      game.selectAbilityTargetAt(Vector2(250, 180));

      expect(game.actionQueue.count, equals(1));
      expect(game.actionQueue.actions.first, isA<SlashAction>());
    });

    test('queueAttackOnEnemy targets the enemy position', () {
      game.startPlanning();
      game.queueAttackOnEnemy();

      expect(game.actionQueue.count, equals(1));
      final action = game.actionQueue.actions.first as SlashAction;
      expect(action.targetPosition.x, closeTo(game.enemy.position.x, 0.01));
      expect(action.targetPosition.y, closeTo(game.enemy.position.y, 0.01));
    });

    test('cancelPlanning clears queue and returns to realtime mode', () {
      game.startPlanning();
      game.queueActionAt(Vector2(100, 100));
      expect(game.actionQueue.isNotEmpty, isTrue);

      game.cancelPlanning();
      expect(game.currentPhase, equals(GamePhase.realtime));
      expect(game.actionQueue.isEmpty, isTrue);
    });

    test('executePlan executes planned actions and returns to realtime', () {
      game.startPlanning();
      game.queueActionAt(Vector2(120, 120));

      game.executePlan();
      expect(game.currentPhase, equals(GamePhase.executing));
      expect(game.player.isExecutingPlan, isTrue);
    });

    test('Enter key initiates planning from realtime, and Enter again returns to realtime', () {
      expect(game.currentPhase, equals(GamePhase.realtime));

      // Press Enter -> Starts planning
      final enterDown = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.enter,
        logicalKey: LogicalKeyboardKey.enter,
        timeStamp: Duration.zero,
      );
      final handled1 = game.onKeyEvent(enterDown, {LogicalKeyboardKey.enter});
      expect(handled1, equals(KeyEventResult.handled));
      expect(game.currentPhase, equals(GamePhase.planning));
      expect(game.selectedActionNotifier.value, equals(ActionType.slash));

      // Press Enter again in planning -> Cancels planning and returns to realtime
      final handled2 = game.onKeyEvent(enterDown, {LogicalKeyboardKey.enter});
      expect(handled2, equals(KeyEventResult.handled));
      expect(game.currentPhase, equals(GamePhase.realtime));
    });

    test('Space key remains reserved for jumping during planning mode', () {
      game.startPlanning();
      game.queueActionAt(Vector2(100, 100));

      // Press Space in planning -> does not execute the queued plan.
      final spaceDown = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.space,
        logicalKey: LogicalKeyboardKey.space,
        timeStamp: Duration.zero,
      );
      final handled = game.onKeyEvent(spaceDown, {LogicalKeyboardKey.space});
      expect(handled, equals(KeyEventResult.ignored));
      expect(game.currentPhase, equals(GamePhase.planning));
      expect(game.actionQueue.isNotEmpty, isTrue);
    });

    test('Space key jumps during realtime mode', () {
      expect(game.currentPhase, equals(GamePhase.realtime));
      expect(game.player.isOnGround, isTrue);

      final spaceDown = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.space,
        logicalKey: LogicalKeyboardKey.space,
        timeStamp: Duration.zero,
      );
      final handled = game.onKeyEvent(spaceDown, {LogicalKeyboardKey.space});
      expect(handled, equals(KeyEventResult.handled));
      expect(game.player.velocity.y, lessThan(0)); // Upward jump velocity
      expect(game.player.isOnGround, isFalse);
    });

    test('Escape key cancels planning', () {
      game.startPlanning();
      expect(game.currentPhase, equals(GamePhase.planning));

      final escDown = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.escape,
        logicalKey: LogicalKeyboardKey.escape,
        timeStamp: Duration.zero,
      );
      final handled = game.onKeyEvent(escDown, {LogicalKeyboardKey.escape});
      expect(handled, equals(KeyEventResult.handled));
      expect(game.currentPhase, equals(GamePhase.realtime));
    });

    test('Player platformer physics lands on ground after falling', () {
      // Position player in the air over open ground (between platforms)
      game.player.position.x = 325;
      game.player.position.y = 100;
      game.player.velocity.y = 0;
      game.player.isOnGround = false;

      // Simulate a few physics steps
      for (int i = 0; i < 30; i++) {
        game.update(0.05);
      }

      // Should have landed on ground
      expect(game.player.isOnGround, isTrue);
      expect(
        game.player.position.y + game.player.size.y / 2,
        closeTo(game.arena.groundY, 0.1),
      );
    });

    test('Player can land on elevated platform', () {
      final plat = game.arena.platforms.first;
      // Position player with feet 20px above the platform
      game.player.position.x = plat.left + plat.width / 2;
      game.player.position.y = plat.top - game.player.size.y / 2 - 20;
      game.player.velocity.y = 80; // Falling down
      game.player.isOnGround = false;

      for (int i = 0; i < 15; i++) {
        game.update(0.02);
      }

      // Should land on platform
      expect(game.player.isOnGround, isTrue);
      expect(
        game.player.position.y + game.player.size.y / 2,
        closeTo(plat.top, 0.1),
      );
    });
  });
}
