import 'package:flutter_test/flutter_test.dart';
import 'package:builds_and_bosses_flame/core/dnd/dice.dart';
import 'package:builds_and_bosses_flame/core/dnd/character_stats.dart';
import 'package:builds_and_bosses_flame/core/dnd/combat_engine.dart';
import 'package:builds_and_bosses_flame/core/actions/action_queue.dart';
import 'package:builds_and_bosses_flame/core/actions/game_action.dart';
import 'package:flame/extensions.dart';

void main() {
  group('D&D Dice Tests', () {
    test('d20 returns values between 1 and 20', () {
      for (int i = 0; i < 100; i++) {
        final roll = Dice.d20();
        expect(roll, greaterThanOrEqualTo(1));
        expect(roll, lessThanOrEqualTo(20));
      }
    });

    test('Advantage returns maximum of two d20 rolls', () {
      for (int i = 0; i < 50; i++) {
        final roll = Dice.d20(advantage: true);
        expect(roll, greaterThanOrEqualTo(1));
        expect(roll, lessThanOrEqualTo(20));
      }
    });
  });

  group('Character Stats Tests', () {
    test('Fighter stats calculate correct modifiers and bonuses', () {
      final fighter = CharacterStats.fighterProtagonist();
      // Strength 16 -> ((16-10)/2) = +3 mod
      expect(fighter.strengthMod, equals(3));
      // Level 3 -> Proficiency +2
      expect(fighter.proficiencyBonus, equals(2));
      // Melee attack bonus = +3 + +2 = +5
      expect(fighter.meleeAttackBonus, equals(5));
      expect(fighter.armorClass, equals(16));
    });

    test('Taking damage and healing', () {
      final fighter = CharacterStats.fighterProtagonist();
      expect(fighter.currentHp, equals(28));
      fighter.takeDamage(10);
      expect(fighter.currentHp, equals(18));
      fighter.heal(5);
      expect(fighter.currentHp, equals(23));
      fighter.heal(100); // Cannot exceed maxHp
      expect(fighter.currentHp, equals(28));
    });
  });

  group('Combat Engine Tests', () {
    test('Resolving attack against target', () {
      final fighter = CharacterStats.fighterProtagonist();
      final dummy = CharacterStats.trainingDummy();

      final initialHp = dummy.currentHp;
      final result = CombatEngine.resolveMeleeAttack(
        attacker: fighter,
        defender: dummy,
      );

      expect(result.rawD20Roll, inInclusiveRange(1, 20));
      expect(result.targetAC, equals(13));

      if (result.isHit) {
        expect(result.damageDealt, greaterThan(0));
        expect(dummy.currentHp, equals(initialHp - result.damageDealt));
      } else {
        expect(result.damageDealt, equals(0));
        expect(dummy.currentHp, equals(initialHp));
      }
    });
  });

  group('Tactical Action Queue Tests', () {
    test('Action queue manages AP correctly and respects budget', () {
      final queue = ActionQueue(maxAP: 100);
      expect(queue.remainingAP, equals(100));

      // Add Move (15 AP)
      final moveAdded = queue.tryAdd(MoveAction(targetPosition: Vector2(100, 100)));
      expect(moveAdded, isTrue);
      expect(queue.spentAP, equals(15));
      expect(queue.remainingAP, equals(85));

      // Add Slash (25 AP)
      final slashAdded = queue.tryAdd(SlashAction(targetPosition: Vector2(100, 100)));
      expect(slashAdded, isTrue);
      expect(queue.spentAP, equals(40));

      // Add Dash (20 AP)
      queue.tryAdd(DashAction(targetPosition: Vector2(200, 100)));
      expect(queue.spentAP, equals(60));

      // Undo last
      final undone = queue.undo();
      expect(undone, isA<DashAction>());
      expect(queue.spentAP, equals(40));
      expect(queue.count, equals(2));

      // Clear
      queue.clear();
      expect(queue.isEmpty, isTrue);
      expect(queue.spentAP, equals(0));
      expect(queue.remainingAP, equals(100));
    });

    test('Queue rejects actions exceeding max AP', () {
      final queue = ActionQueue(maxAP: 30);
      expect(queue.tryAdd(SlashAction(targetPosition: Vector2.zero())), isTrue); // 25 AP
      // Next action costs 15 AP -> 25 + 15 = 40 > 30 -> should fail
      expect(queue.tryAdd(MoveAction(targetPosition: Vector2.zero())), isFalse);
      expect(queue.count, equals(1));
    });
  });
}
