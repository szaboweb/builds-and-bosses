import 'package:flutter_test/flutter_test.dart';

import 'package:builds_and_bosses_flame/core/physics/deterministic_hash.dart';

void main() {
  group('M2: Deterministic Hash (FNV-1a)', () {
    test('identical input sequence yields identical hash', () {
      final inputA = [1000, 2500, -500, 42];
      final inputB = [1000, 2500, -500, 42];

      final hashA = DeterministicHash.hashInts(inputA);
      final hashB = DeterministicHash.hashInts(inputB);

      expect(hashA, equals(hashB));
    });

    test('different input sequence yields different hash', () {
      final hashA = DeterministicHash.hashInts([1, 2, 3]);
      final hashB = DeterministicHash.hashInts([1, 2, 4]);

      expect(hashA, isNot(equals(hashB)));
    });

    test('combine produces deterministic 32-bit output', () {
      final combined = DeterministicHash.combine(12345, 67890);
      expect(combined, equals(DeterministicHash.combine(12345, 67890)));
      expect(combined, isNot(equals(DeterministicHash.combine(67890, 12345))));
    });
  });

  group('M2: Seeded Dice (XorShift32)', () {
    test('two dice instances with same seed produce identical sequence', () {
      final dice1 = SeededDice(42);
      final dice2 = SeededDice(42);

      final rolls1 = List.generate(50, (_) => dice1.d20());
      final rolls2 = List.generate(50, (_) => dice2.d20());

      expect(rolls1, equals(rolls2));
    });

    test('dice instances with different seeds produce different sequences', () {
      final dice1 = SeededDice(42);
      final dice2 = SeededDice(999);

      final rolls1 = List.generate(20, (_) => dice1.d20());
      final rolls2 = List.generate(20, (_) => dice2.d20());

      expect(rolls1, isNot(equals(rolls2)));
    });

    test('rolls stay strictly within dice boundaries', () {
      final dice = SeededDice(1337);

      for (var i = 0; i < 200; i++) {
        final r4 = dice.d4();
        expect(r4, inInclusiveRange(1, 4));

        final r6 = dice.d6();
        expect(r6, inInclusiveRange(1, 6));

        final r8 = dice.d8();
        expect(r8, inInclusiveRange(1, 8));

        final r10 = dice.d10();
        expect(r10, inInclusiveRange(1, 10));

        final r12 = dice.d12();
        expect(r12, inInclusiveRange(1, 12));

        final r20 = dice.d20();
        expect(r20, inInclusiveRange(1, 20));
      }
    });

    test('advantage selects max and disadvantage selects min', () {
      final diceAdv1 = SeededDice(100);
      final diceAdv2 = SeededDice(100);

      // Advantage test: manually roll 2 and compare
      final advRoll = diceAdv1.d20(advantage: true);
      final r1 = diceAdv2.roll(20);
      final r2 = diceAdv2.roll(20);
      final expectedAdv = r1 > r2 ? r1 : r2;
      expect(advRoll, equals(expectedAdv));

      final diceDis1 = SeededDice(200);
      final diceDis2 = SeededDice(200);

      // Disadvantage test: manually roll 2 and compare
      final disRoll = diceDis1.d20(disadvantage: true);
      final d1 = diceDis2.roll(20);
      final d2 = diceDis2.roll(20);
      final expectedDis = d1 < d2 ? d1 : d2;
      expect(disRoll, equals(expectedDis));
    });

    test('zero seed does not break generator', () {
      final diceZero = SeededDice(0);
      expect(diceZero.state, isNot(equals(0)));

      final roll = diceZero.d20();
      expect(roll, inInclusiveRange(1, 20));
    });
  });
}
