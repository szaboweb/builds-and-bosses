import 'event_bus.dart';
import 'status_tracker.dart';
import 'tag_dictionary.dart';

/// Exception thrown when two rules targeting the same event share identical priority.
class RuleConflictException implements Exception {
  final String ruleIdA;
  final String ruleIdB;
  final Type eventType;
  final int priority;

  RuleConflictException({
    required this.ruleIdA,
    required this.ruleIdB,
    required this.eventType,
    required this.priority,
  });

  @override
  String toString() =>
      'RuleConflictException: Rule "$ruleIdA" and "$ruleIdB" have the same '
      'priority $priority on event $eventType';
}

/// Execution context passed to rule action callbacks.
class RuleContext {
  final RuleEvent event;
  final Set<String> activeTags;
  final StatusTracker statusTracker;
  final RuleEventBus eventBus;

  RuleContext({
    required this.event,
    required this.activeTags,
    required this.statusTracker,
    required this.eventBus,
  });
}

/// An emergent rule responding to a specific [RuleEvent] when [when] condition is met.
class Rule {
  final String id;
  final int priority;
  final Type onEventType;
  final TagCondition when;
  final void Function(RuleContext context) then;

  const Rule({
    required this.id,
    required this.priority,
    required this.onEventType,
    required this.when,
    required this.then,
  });
}

/// Deterministic rule engine resolving game events through prioritized tag rules.
class RuleEngine {
  final List<Rule> _rules = [];

  List<Rule> get rules => List.unmodifiable(_rules);

  /// Registers a [Rule].
  /// Throws [RuleConflictException] if another rule for the same event shares identical priority.
  void registerRule(Rule rule) {
    for (final existing in _rules) {
      if (existing.onEventType == rule.onEventType &&
          existing.priority == rule.priority) {
        throw RuleConflictException(
          ruleIdA: existing.id,
          ruleIdB: rule.id,
          eventType: rule.onEventType,
          priority: rule.priority,
        );
      }
    }
    _rules.add(rule);
    _rules.sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// Batch registers an iterable of [Rule]s.
  void registerRules(Iterable<Rule> rules) {
    for (final rule in rules) {
      registerRule(rule);
    }
  }

  /// Dispatches [event] through all matching rules in ascending priority order.
  int dispatch(RuleEvent event, RuleContext context) {
    var executedCount = 0;
    final matchingRules = _rules
        .where((r) => r.onEventType == event.runtimeType)
        .toList(growable: false);

    for (final rule in matchingRules) {
      if (rule.when.matches(context.activeTags)) {
        rule.then(context);
        executedCount++;
      }
    }

    return executedCount;
  }
}
