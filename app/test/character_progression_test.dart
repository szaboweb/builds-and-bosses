import 'package:flutter_test/flutter_test.dart';
import 'package:builds_and_bosses_flame/core/dnd/character_progression.dart';

void main() {
  group('CharacterProgression D&D 5e Rules Tests', () {
    test('Proficiency Bonus scales strictly with level 1 to 20', () {
      expect(CharacterProgression.proficiencyBonusFor(1), equals(2));
      expect(CharacterProgression.proficiencyBonusFor(4), equals(2));
      expect(CharacterProgression.proficiencyBonusFor(5), equals(3));
      expect(CharacterProgression.proficiencyBonusFor(8), equals(3));
      expect(CharacterProgression.proficiencyBonusFor(9), equals(4));
      expect(CharacterProgression.proficiencyBonusFor(12), equals(4));
      expect(CharacterProgression.proficiencyBonusFor(13), equals(5));
      expect(CharacterProgression.proficiencyBonusFor(16), equals(5));
      expect(CharacterProgression.proficiencyBonusFor(17), equals(6));
      expect(CharacterProgression.proficiencyBonusFor(20), equals(6));
    });

    test('Fighter ASI points accumulate up to 14 points at level 20', () {
      expect(CharacterProgression.asiPointsForLevel(1), equals(0));
      expect(CharacterProgression.asiPointsForLevel(3), equals(0));
      expect(CharacterProgression.asiPointsForLevel(4), equals(2));
      expect(CharacterProgression.asiPointsForLevel(6), equals(4));
      expect(CharacterProgression.asiPointsForLevel(8), equals(6));
      expect(CharacterProgression.asiPointsForLevel(12), equals(8));
      expect(CharacterProgression.asiPointsForLevel(14), equals(10));
      expect(CharacterProgression.asiPointsForLevel(16), equals(12));
      expect(CharacterProgression.asiPointsForLevel(19), equals(14));
      expect(CharacterProgression.asiPointsForLevel(20), equals(14));
    });

    test('Max HP scales dynamically from level 1 to level 20 with CON mod', () {
      // Level 1 Fighter with CON 14 (+2 mod): 12 + 2 = 14 HP
      final lvl1Hp = CharacterProgression.calculateMaxHp(1, 2);
      expect(lvl1Hp, equals(14));

      // Level 20 Fighter with CON 20 (+5 mod): (12 + 5) + 19 * (6 + 5) = 17 + 209 = 226 HP
      final lvl20Hp = CharacterProgression.calculateMaxHp(20, 5);
      expect(lvl20Hp, equals(226));
      expect(lvl20Hp, greaterThan(lvl1Hp * 15));
    });

    test('Action Points (AP / Mana) scale dynamically from 100 to 200+ at level 20', () {
      // Level 1: 100 AP
      final lvl1Ap = CharacterProgression.calculateMaxAp(1);
      expect(lvl1Ap, equals(100));

      // Level 20 with WIS 12 (+1 mod): 100 + 19 * 5 + 5 = 200 AP
      final lvl20Ap = CharacterProgression.calculateMaxAp(20, wisMod: 1);
      expect(lvl20Ap, equals(200));
    });

    test(
      'Level 20 Impact analysis identifies HP as the highest relative scaling',
      () {
        final analysis = CharacterProgression.analyzeLevel20Impact(
          baseline: const StatProgressionSnapshot(
            hp: 14,
            ap: 100,
            speed: 180,
            jumpHeight: 86,
            attackBonus: 5,
          ),
          peak: const StatProgressionSnapshot(
            hp: 226,
            ap: 200,
            speed: 240,
            jumpHeight: 138,
            attackBonus: 11,
          ),
        );

        expect(analysis.biggestImpactName, contains('HP'));
        expect(analysis.hpDeltaPercent, greaterThan(1500.0));
        expect(analysis.apDeltaPercent, equals(100.0));
        expect(analysis.speedDeltaPercent, closeTo(33.3, 0.5));
        expect(analysis.jumpDeltaPercent, greaterThan(60.0));
      },
    );
  });
}
