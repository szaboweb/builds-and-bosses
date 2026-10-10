import 'dart:math';

import 'capability_registry.dart';
import 'fixed_units.dart';
import 'modifier.dart';

/// D&D character attribute scores.
class StatScores {
  final int strength;
  final int dexterity;
  final int constitution;
  final int intelligence;
  final int wisdom;
  final int charisma;

  const StatScores({
    this.strength = 10,
    this.dexterity = 10,
    this.constitution = 10,
    this.intelligence = 10,
    this.wisdom = 10,
    this.charisma = 10,
  });

  /// Standard D&D modifier calculation with floor division: floor((score - 10) / 2).
  static int modifierFor(int score) {
    final diff = score - 10;
    return diff >= 0 ? diff ~/ 2 : (diff - 1) ~/ 2;
  }

  int get strMod => modifierFor(strength);
  int get dexMod => modifierFor(dexterity);
  int get conMod => modifierFor(constitution);
  int get intMod => modifierFor(intelligence);
  int get wisMod => modifierFor(wisdom);
  int get chaMod => modifierFor(charisma);
}

/// Fully evaluated physical capabilities in deterministic [Fixed] units.
class DerivedPhysicsStats {
  final Map<Capability, Fixed> _values;

  const DerivedPhysicsStats(this._values);

  Fixed get jumpHeightTiles => _values[Capability.jumpHeight] ?? Fixed.zero;
  Fixed get pushLimitLb => _values[Capability.pushLimit] ?? Fixed.zero;
  Fixed get windResistanceFactor =>
      _values[Capability.windResistance] ?? Fixed.zero;
  Fixed get groundSpeedTilesPerSec =>
      _values[Capability.groundSpeed] ?? Fixed.zero;
  Fixed get flySpeedMultiplier => _values[Capability.flySpeed] ?? Fixed.zero;
  Fixed get slideBrakingFactor =>
      _values[Capability.slideBraking] ?? Fixed.zero;
  Fixed get fallResilienceRatio =>
      _values[Capability.fallResilience] ?? Fixed.zero;
  Fixed get flatDamageReduction =>
      _values[Capability.flatDamageReduction] ?? Fixed.zero;

  Fixed capabilityValue(Capability capability) =>
      _values[capability] ?? Fixed.zero;

  /// The single entry point deriving physical stats from [StatScores] and [modifiers]
  /// per PHYSICS_HANDOFF specification.
  factory DerivedPhysicsStats.derive({
    required StatScores stats,
    Iterable<Modifier> modifiers = const [],
  }) {
    final values = <Capability, Fixed>{};
    _deriveStrengthCapabilities(stats, modifiers, values);
    _deriveDexterityCapabilities(stats, modifiers, values);
    _deriveConstitutionCapabilities(stats, modifiers, values);
    return DerivedPhysicsStats(values);
  }

  static void _deriveStrengthCapabilities(
    StatScores stats,
    Iterable<Modifier> modifiers,
    Map<Capability, Fixed> output,
  ) {
    final strMod = stats.strMod;
    final baseJump = Fixed(max(1000, 2000 + 250 * strMod));
    output[Capability.jumpHeight] = Modifier.evaluate(
      targetCapability: Capability.jumpHeight,
      baseValue: baseJump,
      modifiers: modifiers,
    );

    final basePush = Fixed.fromInt(30 * stats.strength);
    output[Capability.pushLimit] = Modifier.evaluate(
      targetCapability: Capability.pushLimit,
      baseValue: basePush,
      modifiers: modifiers,
    );

    final baseWind = Fixed(max(0, 1000 - 120 * strMod));
    output[Capability.windResistance] = Modifier.evaluate(
      targetCapability: Capability.windResistance,
      baseValue: baseWind,
      modifiers: modifiers,
    );
  }

  static void _deriveDexterityCapabilities(
    StatScores stats,
    Iterable<Modifier> modifiers,
    Map<Capability, Fixed> output,
  ) {
    final dexMod = stats.dexMod;
    output[Capability.groundSpeed] = Modifier.evaluate(
      targetCapability: Capability.groundSpeed,
      baseValue: Fixed(max(0, 5000 + 250 * dexMod)),
      modifiers: modifiers,
    );

    output[Capability.flySpeed] = Modifier.evaluate(
      targetCapability: Capability.flySpeed,
      baseValue: Fixed(max(0, 1000 + 50 * dexMod)),
      modifiers: modifiers,
    );

    output[Capability.slideBraking] = Modifier.evaluate(
      targetCapability: Capability.slideBraking,
      baseValue: Fixed(max(0, 1000 + 150 * dexMod)),
      modifiers: modifiers,
    );

    final baseResilienceRaw = ((stats.dexterity - 8) * 1000) ~/ 16;
    output[Capability.fallResilience] = Modifier.evaluate(
      targetCapability: Capability.fallResilience,
      baseValue: Fixed(baseResilienceRaw.clamp(0, 1000)),
      modifiers: modifiers,
    );
  }

  static void _deriveConstitutionCapabilities(
    StatScores stats,
    Iterable<Modifier> modifiers,
    Map<Capability, Fixed> output,
  ) {
    output[Capability.flatDamageReduction] = Modifier.evaluate(
      targetCapability: Capability.flatDamageReduction,
      baseValue: Fixed.fromInt(max(0, stats.conMod)),
      modifiers: modifiers,
    );
  }
}
