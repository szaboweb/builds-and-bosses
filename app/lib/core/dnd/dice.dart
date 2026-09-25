import 'dart:math';

/// D&D dice rolling system.
class Dice {
  static Random _rng = Random();
  static int? _seed;

  static int? get seed => _seed;

  static void configureSeed(int seed) {
    _seed = seed;
    _rng = Random(seed);
  }

  /// Rolls a single die with [sides].
  static int roll(int sides) {
    if (sides <= 0) return 0;
    return _rng.nextInt(sides) + 1;
  }

  /// Rolls a d20 with optional advantage or disadvantage.
  static int d20({bool advantage = false, bool disadvantage = false}) {
    if (advantage && !disadvantage) {
      final r1 = roll(20);
      final r2 = roll(20);
      return max(r1, r2);
    }
    if (disadvantage && !advantage) {
      final r1 = roll(20);
      final r2 = roll(20);
      return min(r1, r2);
    }
    return roll(20);
  }

  /// Rolls multiple dice of the same type: e.g. 2d6.
  static int rollMultiple(int count, int sides) {
    int total = 0;
    for (int i = 0; i < count; i++) {
      total += roll(sides);
    }
    return total;
  }

  /// Convenience methods for standard D&D dice.
  static int d4([int count = 1]) => rollMultiple(count, 4);
  static int d6([int count = 1]) => rollMultiple(count, 6);
  static int d8([int count = 1]) => rollMultiple(count, 8);
  static int d10([int count = 1]) => rollMultiple(count, 10);
  static int d12([int count = 1]) => rollMultiple(count, 12);
}
