/// Utility providing collision-free, monotonic identifier generation
/// for entities, blueprint platforms, items, and arena triggers.
class UniqueId {
  static int _counter = 0;

  const UniqueId._internal();

  /// Generates a unique identifier combining [prefix], current epoch microseconds,
  /// and a monotonic incrementing counter.
  static String next([String prefix = 'id']) {
    _counter++;
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return '${prefix}_${timestamp}_$_counter';
  }

  /// Resets the internal counter for deterministic unit testing.
  static void resetForTesting() {
    _counter = 0;
  }
}
