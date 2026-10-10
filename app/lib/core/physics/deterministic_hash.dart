/// Platform-independent, deterministic integer hashing and seedable dice
/// using 32-bit integer arithmetic (XorShift32 and FNV-1a) to guarantee
/// bitwise reproducible simulation replay across platforms.
class DeterministicHash {
  static const int fnvOffsetBasis = 0x811C9DC5;
  static const int fnvPrime = 0x01000193;

  /// Hashes an iterable of 32-bit integers into a single 32-bit integer using FNV-1a.
  static int hashInts(Iterable<int> values, [int seed = fnvOffsetBasis]) {
    var hash = seed & 0xFFFFFFFF;
    for (final val in values) {
      hash ^= (val & 0xFFFFFFFF);
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// Combines two 32-bit integers deterministically.
  static int combine(int a, int b) {
    var hash = fnvOffsetBasis;
    hash = ((hash ^ (a & 0xFFFFFFFF)) * fnvPrime) & 0xFFFFFFFF;
    hash = ((hash ^ (b & 0xFFFFFFFF)) * fnvPrime) & 0xFFFFFFFF;
    return hash;
  }
}

/// A deterministic pseudo-random number generator and dice roller using XorShift32.
/// Guarantees that identical seed + sequence of rolls yields identical outcomes.
class SeededDice {
  int _state;

  SeededDice(int seed)
    : _state = (seed & 0xFFFFFFFF) == 0 ? 0x12345678 : (seed & 0xFFFFFFFF);

  int get state => _state;

  /// Generates the next pseudo-random non-negative 32-bit integer below [maxExclusive].
  int nextInt(int maxExclusive) {
    if (maxExclusive <= 0) return 0;

    // XorShift32 algorithm (32-bit integer arithmetic)
    var x = _state;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= (x >> 17) & 0xFFFFFFFF;
    x ^= (x << 5) & 0xFFFFFFFF;
    _state = x & 0xFFFFFFFF;

    final unsignedValue = _state & 0x7FFFFFFF;
    return unsignedValue % maxExclusive;
  }

  /// Rolls a single die with [sides] (e.g. 6 for d6, 20 for d20). Result is 1..sides.
  int roll(int sides) {
    if (sides <= 0) return 0;
    return nextInt(sides) + 1;
  }

  /// Rolls a d20 with optional advantage or disadvantage.
  int d20({bool advantage = false, bool disadvantage = false}) {
    if (advantage && !disadvantage) {
      final r1 = roll(20);
      final r2 = roll(20);
      return r1 > r2 ? r1 : r2;
    }
    if (disadvantage && !advantage) {
      final r1 = roll(20);
      final r2 = roll(20);
      return r1 < r2 ? r1 : r2;
    }
    return roll(20);
  }

  /// Rolls multiple dice of the same type: e.g. 2d6.
  int rollMultiple(int count, int sides) {
    var total = 0;
    for (var i = 0; i < count; i++) {
      total += roll(sides);
    }
    return total;
  }

  int d4([int count = 1]) => rollMultiple(count, 4);
  int d6([int count = 1]) => rollMultiple(count, 6);
  int d8([int count = 1]) => rollMultiple(count, 8);
  int d10([int count = 1]) => rollMultiple(count, 10);
  int d12([int count = 1]) => rollMultiple(count, 12);
}
