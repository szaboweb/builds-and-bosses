import 'package:flutter_test/flutter_test.dart';

import 'package:builds_and_bosses_flame/core/physics/damage_pipeline.dart';
import 'package:builds_and_bosses_flame/core/physics/derived_stats.dart';

void main() {
  const pipeline = DamagePipeline();

  group('M5: Golden Table Verification (PHYSICS_HANDOFF 2.4)', () {
    test('8 tiles fall matches golden table across DEX thresholds', () {
      final dex8 = DerivedPhysicsStats.derive(
        stats: const StatScores(dexterity: 8),
      );
      final dex14 = DerivedPhysicsStats.derive(
        stats: const StatScores(dexterity: 14),
      );
      final dex20 = DerivedPhysicsStats.derive(
        stats: const StatScores(dexterity: 20),
      );
      final dex24 = DerivedPhysicsStats.derive(
        stats: const StatScores(dexterity: 24),
      );

      final res8 = pipeline.resolve(
        category: DamageCategory.fall,
        equivalentHeightTiles: 8,
        derivedStats: dex8,
        currentHp: 100,
      );
      expect(res8.rawDamage, equals(18));
      expect(res8.finalHpDamage, equals(18));

      final res14 = pipeline.resolve(
        category: DamageCategory.fall,
        equivalentHeightTiles: 8,
        derivedStats: dex14,
        currentHp: 100,
      );
      expect(res14.rawDamage, equals(18));
      expect(res14.finalHpDamage, equals(11)); // Golden: 11

      final res20 = pipeline.resolve(
        category: DamageCategory.fall,
        equivalentHeightTiles: 8,
        derivedStats: dex20,
        currentHp: 100,
      );
      expect(res20.rawDamage, equals(18));
      expect(res20.finalHpDamage, equals(4)); // Golden: 4

      final res24 = pipeline.resolve(
        category: DamageCategory.fall,
        equivalentHeightTiles: 8,
        derivedStats: dex24,
        currentHp: 100,
      );
      expect(res24.rawDamage, equals(18));
      expect(res24.finalHpDamage, equals(0)); // 100% absorption -> 0
    });

    test(
      '12 tiles fall (8 tiles + 4 throw equivalent) matches golden table',
      () {
        final dex8 = DerivedPhysicsStats.derive(
          stats: const StatScores(dexterity: 8),
        );
        final dex14 = DerivedPhysicsStats.derive(
          stats: const StatScores(dexterity: 14),
        );
        final dex20 = DerivedPhysicsStats.derive(
          stats: const StatScores(dexterity: 20),
        );

        final res8 = pipeline.resolve(
          category: DamageCategory.fall,
          equivalentHeightTiles: 12,
          derivedStats: dex8,
          currentHp: 100,
        );
        expect(res8.rawDamage, equals(30));
        expect(res8.finalHpDamage, equals(30));

        final res14 = pipeline.resolve(
          category: DamageCategory.fall,
          equivalentHeightTiles: 12,
          derivedStats: dex14,
          currentHp: 100,
        );
        expect(res14.rawDamage, equals(30));
        expect(res14.finalHpDamage, equals(18)); // Golden: 18

        final res20 = pipeline.resolve(
          category: DamageCategory.fall,
          equivalentHeightTiles: 12,
          derivedStats: dex20,
          currentHp: 100,
        );
        expect(res20.rawDamage, equals(30));
        expect(res20.finalHpDamage, equals(7)); // Golden: 7
      },
    );

    test('Feather fall / safe height (hEq <= 2) deals zero damage', () {
      final dex10 = DerivedPhysicsStats.derive(
        stats: const StatScores(dexterity: 10),
      );
      final res = pipeline.resolve(
        category: DamageCategory.fall,
        equivalentHeightTiles: 2,
        derivedStats: dex10,
        currentHp: 100,
      );
      expect(res.rawDamage, equals(0));
      expect(res.finalHpDamage, equals(0));
    });

    test(
      'equivalent height is strictly capped at maxEquivalentHeight (20 tiles)',
      () {
        final dex10 = DerivedPhysicsStats.derive(
          stats: const StatScores(dexterity: 10),
        );
        final resCapped = pipeline.resolve(
          category: DamageCategory.fall,
          equivalentHeightTiles: 50,
          derivedStats: dex10,
          currentHp: 100,
        );
        // (20 - 2) * 3 = 54 max raw damage
        expect(resCapped.rawDamage, equals(54));
      },
    );
  });

  group('M5: Defense Layer Separation & Step Invariants', () {
    test('CON flat reduction applies to impact and crush, NEVER to fall', () {
      final statsCon16 = DerivedPhysicsStats.derive(
        stats: const StatScores(dexterity: 10, constitution: 16), // CONmod = +3
      );

      final resFall = pipeline.resolve(
        category: DamageCategory.fall,
        equivalentHeightTiles: 6, // (6 - 2) * 3 = 12 raw damage
        derivedStats: statsCon16,
        currentHp: 50,
      );
      // Fall does NOT reduce from CON!
      expect(resFall.afterConReduction, equals(resFall.afterDexResilience));

      final resImpact = pipeline.resolve(
        category: DamageCategory.impact,
        equivalentHeightTiles: 6,
        derivedStats: statsCon16,
        currentHp: 50,
      );
      // Impact DOES reduce by 3 (from 12 -> 9)
      expect(resImpact.rawDamage, equals(12));
      expect(resImpact.afterConReduction, equals(9));
    });

    test('CON flat reduction leaves at least 1 damage remaining', () {
      final godlikeCon = DerivedPhysicsStats.derive(
        stats: const StatScores(constitution: 30), // CONmod = +10
      );

      final resImpact = pipeline.resolve(
        category: DamageCategory.impact,
        equivalentHeightTiles: 3, // (3 - 2) * 3 = 3 raw damage
        derivedStats: godlikeCon,
        currentHp: 50,
      );
      // Raw 3 minus 10 reduction leaves minimum 1 damage
      expect(resImpact.afterConReduction, equals(1));
    });

    test('DEX resilience applies to fall, NEVER to impact', () {
      final agileHero = DerivedPhysicsStats.derive(
        stats: const StatScores(dexterity: 24), // 100% fall absorption
      );

      final resImpact = pipeline.resolve(
        category: DamageCategory.impact,
        equivalentHeightTiles: 8,
        derivedStats: agileHero,
        currentHp: 50,
      );
      // Impact does NOT get DEX absorption!
      expect(resImpact.afterDexResilience, equals(resImpact.afterAbsorption));
      expect(resImpact.finalHpDamage, equals(18));
    });

    test('Stoneskin resistance halves damage AFTER CON reduction', () {
      final fighter = DerivedPhysicsStats.derive(
        stats: const StatScores(constitution: 14), // CONmod = 2
      );

      final res = pipeline.resolve(
        category: DamageCategory.impact,
        equivalentHeightTiles: 6, // 12 raw
        derivedStats: fighter,
        hasResistance: true, // Stoneskin
        currentHp: 50,
      );

      // Raw = 12
      // After CON = 12 - 2 = 10
      // After Resistance = 10 / 2 = 5
      expect(res.rawDamage, equals(12));
      expect(res.afterConReduction, equals(10));
      expect(res.afterResistanceMultiplier, equals(5));
      expect(res.finalHpDamage, equals(5));
    });

    test('temp HP absorbs damage first before HP is touched', () {
      final stats = DerivedPhysicsStats.derive(stats: const StatScores());

      final res = pipeline.resolve(
        category: DamageCategory.fall,
        equivalentHeightTiles:
            6, // 12 raw -> DEX 10 (12.5%): 12 * 875 / 1000 = 10 damage
        derivedStats: stats,
        currentHp: 40,
        currentTempHp: 6,
      );

      expect(res.afterDexResilience, equals(10));
      expect(res.tempHpAbsorbed, equals(6));
      expect(res.remainingTempHp, equals(0));
      expect(res.finalHpDamage, equals(4)); // 10 - 6 = 4 to real HP
      expect(res.remainingHp, equals(36)); // 40 - 4 = 36
    });

    test('obstacle absorption reduces impact damage when movable', () {
      final strongFighter = DerivedPhysicsStats.derive(
        stats: const StatScores(strength: 16), // pushLimit = 480 lb
      );

      const lightCrate = ObstacleAbsorptionInfo(
        isFixed: false,
        weightLb: 100, // movable crate
      );

      final res = pipeline.resolve(
        category: DamageCategory.impact,
        equivalentHeightTiles: 8,
        derivedStats: strongFighter,
        obstacle: lightCrate,
        currentHp: 50,
      );

      // Kinetic absorption occurred!
      expect(res.afterAbsorption, lessThan(res.rawDamage));
    });
  });
}
