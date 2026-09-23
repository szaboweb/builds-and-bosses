import 'package:flutter_test/flutter_test.dart';
import 'package:builds_and_bosses_flame/core/config/game_rules_config.dart';
import 'package:builds_and_bosses_flame/core/dnd/character_stats.dart';

void main() {
  group('PhysicsConfig and Stat-Driven Scaling Tests', () {
    final config = GameRulesConfig.standard;

    test('Jump velocity and peak height scale dynamically with Strength modifier', () {
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
    });

    test('Horizontal movement speed scales dynamically with Dexterity modifier', () {
      // DEX 10 (+0 mod)
      expect(config.physics.calculateMoveSpeed(0), equals(180.0));
      // DEX 12 (+1 mod)
      expect(config.physics.calculateMoveSpeed(1), equals(192.0));
      // DEX 18 (+4 mod)
      expect(config.physics.calculateMoveSpeed(4), equals(228.0));
    });

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

  group('PointBuyConfig Tests', () {
    final pointBuy = GameRulesConfig.standard.pointBuy;

    test('Point buy cost table matches DDO 28-point specifications', () {
      expect(pointBuy.costForScore(8), equals(0));
      expect(pointBuy.costForScore(9), equals(1));
      expect(pointBuy.costForScore(14), equals(6));
      expect(pointBuy.costForScore(15), equals(8));
      expect(pointBuy.costForScore(16), equals(10));
      expect(pointBuy.costForScore(17), equals(13));
      expect(pointBuy.costForScore(18), equals(16));
    });

    test('Point buy budget calculation and validation', () {
      // All 8s costs 0 points -> 28 remaining
      final startingScores = {
        'STR': 8,
        'DEX': 8,
        'CON': 8,
        'INT': 8,
        'WIS': 8,
        'CHA': 8,
      };
      expect(pointBuy.calculateTotalSpent(startingScores), equals(0));
      expect(pointBuy.remainingPoints(startingScores), equals(28));

      // Standard fighter: 16, 12, 14, 10, 12, 10
      // Costs: 16->10, 12->4, 14->6, 10->2, 12->4, 10->2 = 28 points exactly!
      final fighterScores = {
        'STR': 16,
        'DEX': 12,
        'CON': 14,
        'INT': 10,
        'WIS': 12,
        'CHA': 10,
      };
      expect(pointBuy.calculateTotalSpent(fighterScores), equals(28));
      expect(pointBuy.remainingPoints(fighterScores), equals(0));

      // Cannot increase any stat further when at 0 points
      expect(pointBuy.canIncrease(fighterScores, 'STR'), isFalse);
      // Can decrease
      expect(pointBuy.canDecrease(fighterScores, 'STR'), isTrue);
    });
  });

  group('CharacterStats JSON Serialization Tests', () {
    test('Serializes to and from JSON preserving all 6 ability scores', () {
      final hero = CharacterStats(
        name: 'Paladin',
        level: 4,
        maxHp: 36,
        armorClass: 18,
        strength: 16,
        dexterity: 10,
        constitution: 14,
        intelligence: 8,
        wisdom: 12,
        charisma: 16,
      );

      final json = hero.toJson();
      expect(json['name'], equals('Paladin'));
      expect(json['strength'], equals(16));
      expect(json['charisma'], equals(16));

      final restored = CharacterStats.fromJson(json);
      expect(restored.name, equals('Paladin'));
      expect(restored.strength, equals(16));
      expect(restored.charisma, equals(16));
      expect(restored.jumpVelocity, equals(hero.jumpVelocity));
    });
  });
}
