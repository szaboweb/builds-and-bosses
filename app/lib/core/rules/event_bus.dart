/// Abstract base class for all rules engine events.
abstract class RuleEvent {
  final int tick;
  const RuleEvent({required this.tick});
}

/// A deterministic, synchronous event bus with chain depth limiting
/// to prevent runaway cascade loops in game physics and emergent rules.
class RuleEventBus {
  final int maxChainDepth;
  final Map<Type, List<void Function(RuleEvent)>> _handlers = {};
  int _currentDepth = 0;

  RuleEventBus({this.maxChainDepth = 16});

  int get currentDepth => _currentDepth;

  /// Subscribes a typed handler to events of type [T].
  void subscribe<T extends RuleEvent>(void Function(T event) handler) {
    final list = _handlers.putIfAbsent(T, () => []);
    list.add((e) => handler(e as T));
  }

  /// Publishes an event synchronously to all registered listeners.
  /// Throws [StateError] if cascading handler calls exceed [maxChainDepth].
  void publish(RuleEvent event) {
    if (_currentDepth >= maxChainDepth) {
      throw StateError(
        'RuleEventBus exceeded max chain depth of $maxChainDepth on event ${event.runtimeType}',
      );
    }

    _currentDepth++;
    try {
      final handlers = _handlers[event.runtimeType];
      if (handlers != null) {
        final snapshot = List<void Function(RuleEvent)>.of(handlers);
        for (final handler in snapshot) {
          handler(event);
        }
      }
    } finally {
      _currentDepth--;
    }
  }

  /// Clears all subscribed handlers and resets recursion depth.
  void clear() {
    _handlers.clear();
    _currentDepth = 0;
  }
}
