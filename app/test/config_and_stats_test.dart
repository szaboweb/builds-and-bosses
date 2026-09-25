import 'package:flutter_test/flutter_test.dart';
import 'package:builds_and_bosses_flame/core/config/game_rules_config.dart';
import 'package:builds_and_bosses_flame/core/dnd/character_catalog.dart';
import 'package:builds_and_bosses_flame/core/dnd/character_stats.dart';

void main() {
  group('PhysicsConfig and Stat-Driven Scaling Tests', () {
    final config = GameRulesConfig.standard;

    test(
      'Jump velocity and peak height scale dynamically with Strength modifier',
      () {
        // STR 10 (+0 mod)
        final jumpVel10 = config.physics.calculateJumpVelocity(0);
        final jumpHeight10 = config.physics.calculateJumpHeight(0);
        expect(jumpVel10, equals(-410.0));
        expect(jumpHeight10, closeTo(85.76, 0.5));

        // STR 16 (+3 mod)
        final jumpVel16 = config.physics.calculateJumpVelocity(3);
        final jumpHeight16 = config.physics.calculateJumpHeight(3);
        expect(jumpVel16, equals(-476.0));
        expect(jumpHeight16, closeTo(115.6, 0.5));
        // Confirms clearance of the 103 px elevated stone platforms
        expect(jumpHeight16, greaterThan(103.0));

        // STR 20 (+5 mod)
        final jumpVel20 = config.physics.calculateJumpVelocity(5);
        final jumpHeight20 = config.physics.calculateJumpHeight(5);
        expect(jumpVel20, equals(-520.0));
        expect(jumpHeight20, closeTo(138.0, 0.5));
        expect(jumpHeight20, greaterThan(jumpHeight16));
      },
    );

    test(
      'Horizontal movement speed scales dynamically with Dexterity modifier',
      () {
        // DEX 10 (+0 mod)
        expect(config.physics.calculateMoveSpeed(0), equals(180.0));
        // DEX 12 (+1 mod)
        expect(config.physics.calculateMoveSpeed(1), equals(192.0));
        // DEX 18 (+4 mod)
        expect(config.physics.calculateMoveSpeed(4), equals(228.0));
      },
    );

    test('CharacterStats dynamic getters read directly from config', () {
      final hero = CharacterStats(
        name: 'Strongman',
        maxHp: 30,
        armorClass: 15,
        strength: 18, // +4 mod -> -410 - (4*22) = -498 px/s
        dexterity: 14, // +2 mod -> 180 + (2*12) = 204 px/s
        constitution: 16,
      );

      expect(hero.strengthMod, equals(4));
      expect(hero.jumpVelocity, equals(-498.0));
      expect(hero.maxJumpHeight, closeTo(126.5, 0.5));
      expect(hero.dexterityMod, equals(2));
      expect(hero.moveSpeed, equals(204.0));
    });

    test('Custom config injection overrides physics formulas cleanly', () {
      const customConfig = GameRulesConfig(
        physics: PhysicsConfig(
          baseGravity: 500.0, // Low gravity moon arena
          baseJumpVelocity: -300.0,
          strJumpVelocityScaling: -50.0,
        ),
      );

      final hero = CharacterStats(
        name: 'Moon Knight',
        maxHp: 30,
        armorClass: 15,
        strength: 16, // +3 mod -> -300 + (3 * -50) = -450 px/s
        config: customConfig,
      );

      expect(hero.jumpVelocity, equals(-450.0));
      // h = 450^2 / (2 * 500) = 202500 / 1000 = 202.5 px
      expect(hero.maxJumpHeight, equals(202.5));
    });
  });

  test('Combat ranges are configurable and serialized', () {
    const config = CombatConfig(
      meleeRange: 100,
      rangedNormalRange: 400,
      rangedLongRange: 800,
      spellRange: 600,
    );
    final restored = CombatConfig.fromJson(config.toJson());

    expect(restored.meleeRange, equals(100));
    expect(restored.meleeVerticalTolerance, equals(1.5));
    expect(restored.rangedNormalRange, equals(400));
    expect(restored.rangedLongRange, equals(800));
    expect(restored.spellRange, equals(600));
  });

  test('Weapon profiles separate melee reach from dagger thrown range', () {
    final dagger = CharacterStats(
      name: 'Rogue',
      weaponId: 'dagger',
      rangedWeaponId: 'dagger',
      maxHp: 20,
      armorClass: 14,
    );
    final greatsword = CharacterStats(
      name: 'Fighter',
      weaponId: 'greatsword',
      maxHp: 20,
      armorClass: 14,
    );

    expect(dagger.meleeRange, equals(110.0));
    expect(dagger.thrownNormalRange, equals(400.0));
    expect(dagger.thrownLongRange, equals(1200.0));
    expect(greatsword.meleeRange, equals(110.0));
    expect(greatsword.meleeStagger, equals(24.0));
    expect(greatsword.copyWith(strength: 18).meleeStagger, equals(40.0));
    expect(greatsword.copyWith(strength: 8).meleeStagger, equals(20.0));
    expect(dagger.rangedKnockback, equals(0.0));
    expect(greatsword.thrownNormalRange, isNull);
  });

  group('PointBuyConfig Tests', () {
    final pointBuy = GameRulesConfig.standard.pointBuy;

    test('Point buy cost table matches the 2024 Free Rules', () {
      expect(pointBuy.costForScore(8), equals(0));
      expect(pointBuy.costForScore(9), equals(1));
      expect(pointBuy.costForScore(14), equals(7));
      expect(pointBuy.costForScore(15), equals(9));
      expect(pointBuy.costForScore(16), equals(12));
      expect(pointBuy.costForScore(17), equals(15));
      expect(pointBuy.costForScore(18), equals(19));
      expect(pointBuy.totalBudget, equals(27));
    });

    test('Point buy budget calculation and validation', () {
      // All 8s costs 0 points -> 27 remaining
      final startingScores = {
        'STR': 8,
        'DEX': 8,
        'CON': 8,
        'INT': 8,
        'WIS': 8,
        'CHA': 8,
      };
      expect(pointBuy.calculateTotalSpent(startingScores), equals(0));
      expect(pointBuy.remainingPoints(startingScores), equals(27));

      // Standard-array fighter assignment: 15, 14, 13, 10, 12, 8.
      // Costs: 9 + 7 + 5 + 2 + 4 + 0 = 27 points exactly.
      final fighterScores = {
        'STR': 15,
        'DEX': 14,
        'CON': 13,
        'INT': 10,
        'WIS': 12,
        'CHA': 8,
      };
      expect(pointBuy.calculateTotalSpent(fighterScores), equals(27));
      expect(pointBuy.remainingPoints(fighterScores), equals(0));

      // Cannot increase any stat further when at 0 points
      expect(pointBuy.canIncrease(fighterScores, 'STR'), isFalse);
      // Can decrease
      expect(pointBuy.canDecrease(fighterScores, 'STR'), isTrue);
    });
  });

  group('Alignment Equipment Gate Tests', () {
    test(
      'The nine alignments map to the matching alignment-based equipment sets',
      () {
        final lawfulSet = CharacterCatalog.equipmentSets.firstWhere(
          (set) => set.id == 'lawful_order_set',
        );
        final neutralSet = CharacterCatalog.equipmentSets.firstWhere(
          (set) => set.id == 'balanced_guardian_set',
        );
        final chaoticSet = CharacterCatalog.equipmentSets.firstWhere(
          (set) => set.id == 'chaotic_rebel_set',
        );

        expect(lawfulSet.isAllowedFor(CharacterAlignment.lawfulGood), isTrue);
        expect(
          lawfulSet.isAllowedFor(CharacterAlignment.lawfulNeutral),
          isTrue,
        );
        expect(lawfulSet.isAllowedFor(CharacterAlignment.lawfulEvil), isTrue);
        expect(lawfulSet.isAllowedFor(CharacterAlignment.neutralGood), isFalse);

        expect(neutralSet.isAllowedFor(CharacterAlignment.neutral), isTrue);
        expect(neutralSet.isAllowedFor(CharacterAlignment.neutralGood), isTrue);
        expect(neutralSet.isAllowedFor(CharacterAlignment.neutralEvil), isTrue);

        expect(chaoticSet.isAllowedFor(CharacterAlignment.chaoticGood), isTrue);
        expect(
          chaoticSet.isAllowedFor(CharacterAlignment.chaoticNeutral),
          isTrue,
        );
        expect(chaoticSet.isAllowedFor(CharacterAlignment.chaoticEvil), isTrue);
      },
    );

    test(
      'Characters can only wear equipment sets matching their alignment',
      () {
        final lawfulHero = CharacterStats(
          name: 'Paladin',
          maxHp: 30,
          armorClass: 16,
          alignment: CharacterAlignment.lawfulGood,
        );
        final neutralHero = CharacterStats(
          name: 'Scout',
          maxHp: 30,
          armorClass: 14,
          alignment: CharacterAlignment.neutral,
        );
        final chaoticHero = CharacterStats(
          name: 'Rebel',
          maxHp: 30,
          armorClass: 13,
          alignment: CharacterAlignment.chaoticNeutral,
        );

        final lawfulSet = CharacterCatalog.equipmentSets.firstWhere(
          (set) => set.id == 'lawful_order_set',
        );
        final neutralSet = CharacterCatalog.equipmentSets.firstWhere(
          (set) => set.id == 'balanced_guardian_set',
        );
        final chaoticSet = CharacterCatalog.equipmentSets.firstWhere(
          (set) => set.id == 'chaotic_rebel_set',
        );

        expect(lawfulHero.canWearEquipmentSet(lawfulSet), isTrue);
        expect(lawfulHero.canWearEquipmentSet(neutralSet), isFalse);
        expect(neutralHero.canWearEquipmentSet(neutralSet), isTrue);
        expect(chaoticHero.canWearEquipmentSet(chaoticSet), isTrue);
        expect(chaoticHero.canWearEquipmentSet(lawfulSet), isFalse);
      },
    );
  });

  group('CharacterStats JSON Serialization Tests', () {
    test('Serializes to and from JSON preserving all 6 ability scores', () {
      final hero = CharacterStats(
        name: 'Paladin',
        level: 4,
        maxHp: 36,
        armorClass: 18,
        alignment: CharacterAlignment.lawfulGood,
        strength: 16,
        dexterity: 10,
        constitution: 14,
        intelligence: 8,
        wisdom: 12,
        charisma: 16,
      );

      final json = hero.toJson();
      expect(json['name'], equals('Paladin'));
      expect(json['alignment'], equals('LG'));
      expect(json['strength'], equals(16));
      expect(json['charisma'], equals(16));

      final restored = CharacterStats.fromJson(json);
      expect(restored.name, equals('Paladin'));
      expect(restored.alignment, equals(CharacterAlignment.lawfulGood));
      expect(restored.strength, equals(16));
      expect(restored.charisma, equals(16));
      expect(restored.jumpVelocity, equals(hero.jumpVelocity));
    });
  });
}
