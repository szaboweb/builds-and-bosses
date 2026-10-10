import 'package:flutter_test/flutter_test.dart';

import 'package:builds_and_bosses_flame/core/physics/capability_registry.dart';
import 'package:builds_and_bosses_flame/core/physics/derived_stats.dart';
import 'package:builds_and_bosses_flame/core/physics/fixed_units.dart';
import 'package:builds_and_bosses_flame/core/physics/modifier.dart';

void main() {
  group('M1: Fixed-Point Arithmetic (Fixed)', () {
    test('conversions between units, tiles, and feet', () {
      final oneTile = Fixed.fromTiles(1);
      expect(oneTile.raw, equals(1000));
      expect(oneTile.toIntFloor(), equals(1));
      expect(oneTile.toFeetFloor(), equals(5));

      final fiveFeet = Fixed.fromFeet(5);
      expect(fiveFeet.raw, equals(1000));
      expect(fiveFeet.hasSameValue(oneTile), isTrue);

      final halfTile = Fixed.fromMilli(500);
      expect(halfTile.toString(), equals('0.500'));
    });

    test('multiplication and division use floor rounding', () {
      final a = Fixed(1500); // 1.5
      final b = Fixed(2000); // 2.0
      expect(a.mulFixed(b).raw, equals(3000));

      // 1.5 / 2.0 = 0.75
      expect(a.divFixed(b).raw, equals(750));

      // Negative floor division
      final neg = Fixed(-1500);
      expect(neg.divInt(2).raw, equals(-750));
      expect(neg.mulFixed(Fixed(1000)).raw, equals(-1500));
    });

    test('clamping and comparisons', () {
      final val = Fixed(1500);
      expect(val.clamp(Fixed(1000), Fixed(2000)).raw, equals(1500));
      expect(val.clamp(Fixed(2000), Fixed(3000)).raw, equals(2000));
      expect(val.clamp(Fixed(500), Fixed(1000)).raw, equals(1000));
      expect(Fixed(1000).isLessThan(Fixed(2000)), isTrue);
      expect(Fixed(2000).isGreaterThan(Fixed(1000)), isTrue);
    });
  });

  group('M1: CapabilityRegistry', () {
    test('every capability has exactly one owner stat', () {
      final registry = CapabilityRegistry.instance;
      expect(registry.validateCompleteness(), isTrue);

      expect(
        registry.ownerOf(Capability.jumpHeight),
        equals(PrimaryStat.strength),
      );
      expect(
        registry.ownerOf(Capability.pushLimit),
        equals(PrimaryStat.strength),
      );
      expect(
        registry.ownerOf(Capability.windResistance),
        equals(PrimaryStat.strength),
      );

      expect(
        registry.ownerOf(Capability.groundSpeed),
        equals(PrimaryStat.dexterity),
      );
      expect(
        registry.ownerOf(Capability.flySpeed),
        equals(PrimaryStat.dexterity),
      );
      expect(
        registry.ownerOf(Capability.slideBraking),
        equals(PrimaryStat.dexterity),
      );
      expect(
        registry.ownerOf(Capability.fallResilience),
        equals(PrimaryStat.dexterity),
      );

      expect(
        registry.ownerOf(Capability.flatDamageReduction),
        equals(PrimaryStat.constitution),
      );
    });

    test('fails if duplicate or conflicting owner is registered', () {
      final custom = CapabilityRegistry.custom({
        Capability.jumpHeight: PrimaryStat.strength,
      });

      expect(
        () => custom.register(Capability.jumpHeight, PrimaryStat.dexterity),
        throwsStateError,
      );
    });
  });

  group('M1: Modifier Model & Priority Evaluation', () {
    test('scope strictly isolates modifiers', () {
      final baseSpeed = Fixed(5000);
      final fallOnlyModifier = Modifier(
        id: 'cats_grace',
        kind: ModifierKind.add,
        value: Fixed(2000),
        scope: const {Capability.fallResilience},
      );

      final evaluatedSpeed = Modifier.evaluate(
        targetCapability: Capability.groundSpeed,
        baseValue: baseSpeed,
        modifiers: [fallOnlyModifier],
      );

      expect(evaluatedSpeed.raw, equals(baseSpeed.raw));
    });

    test('evaluation order: base -> add -> mul (no group stacking) -> override -> cap', () {
      final base = Fixed(1000);

      final addMod = Modifier(
        id: 'boots',
        kind: ModifierKind.add,
        value: Fixed(500),
        scope: const {Capability.groundSpeed},
      );

      final mulGroup1A = Modifier(
        id: 'haste',
        kind: ModifierKind.mul,
        value: Fixed(2000), // x2.0
        scope: const {Capability.groundSpeed},
        sourceGroup: 'spell_speed',
      );

      final mulGroup1B = Modifier(
        id: 'longstrider',
        kind: ModifierKind.mul,
        value: Fixed(1500), // x1.5 (same group, smaller -> ignored!)
        scope: const {Capability.groundSpeed},
        sourceGroup: 'spell_speed',
      );

      // (1000 + 500) * 2.0 = 3000
      final evaluated = Modifier.evaluate(
        targetCapability: Capability.groundSpeed,
        baseValue: base,
        modifiers: [addMod, mulGroup1A, mulGroup1B],
      );

      expect(evaluated.raw, equals(3000));
    });

    test('override replaces value and cap enforces ceiling', () {
      final base = Fixed(1000);

      final overrideMod = Modifier(
        id: 'polymorph',
        kind: ModifierKind.overrideVal,
        value: Fixed(8000),
        scope: const {Capability.groundSpeed},
        priority: 10,
      );

      final capMod = Modifier(
        id: 'speed_cap',
        kind: ModifierKind.cap,
        value: Fixed(6000),
        scope: const {Capability.groundSpeed},
      );

      final evaluated = Modifier.evaluate(
        targetCapability: Capability.groundSpeed,
        baseValue: base,
        modifiers: [overrideMod, capMod],
      );

      expect(evaluated.raw, equals(6000));
    });
  });

  group('M1: DerivedPhysicsStats & Golden Table Verification', () {
    test(
      'DEX Fall Resilience exactly matches PHYSICS_HANDOFF 2.4 golden table',
      () {
        final dexValues = [8, 10, 14, 16, 20, 22, 24, 30];
        final expectedMilli = [0, 125, 375, 500, 750, 875, 1000, 1000];

        for (var i = 0; i < dexValues.length; i++) {
          final stats = StatScores(dexterity: dexValues[i]);
          final derived = DerivedPhysicsStats.derive(stats: stats);
          expect(
            derived.fallResilienceRatio.raw,
            equals(expectedMilli[i]),
            reason: 'Failed for DEX ${dexValues[i]}',
          );
        }
      },
    );

    test('STR jump height and push limit formulas', () {
      // STR 10 (mod 0) -> 2.0 tiles, 300 lb
      final normal = DerivedPhysicsStats.derive(
        stats: const StatScores(strength: 10),
      );
      expect(normal.jumpHeightTiles.raw, equals(2000));
      expect(normal.pushLimitLb.raw, equals(300000));

      // STR 18 (mod 4) -> 2.0 + 0.25*4 = 3.0 tiles, 540 lb
      final strong = DerivedPhysicsStats.derive(
        stats: const StatScores(strength: 18),
      );
      expect(strong.jumpHeightTiles.raw, equals(3000));
      expect(strong.pushLimitLb.raw, equals(540000));

      // STR 1 (mod -5) -> minimum 1.0 tile
      final weak = DerivedPhysicsStats.derive(
        stats: const StatScores(strength: 1),
      );
      expect(weak.jumpHeightTiles.raw, equals(1000));
    });

    test('CON flat damage reduction', () {
      final con10 = DerivedPhysicsStats.derive(
        stats: const StatScores(constitution: 10),
      );
      expect(con10.flatDamageReduction.raw, equals(0));

      final con14 = DerivedPhysicsStats.derive(
        stats: const StatScores(constitution: 14),
      );
      expect(con14.flatDamageReduction.raw, equals(2000));
    });
  });
}
