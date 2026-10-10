import 'package:flutter_test/flutter_test.dart';

import 'package:builds_and_bosses_flame/core/rules/event_bus.dart';
import 'package:builds_and_bosses_flame/core/rules/rule_engine.dart';
import 'package:builds_and_bosses_flame/core/rules/status_tracker.dart';
import 'package:builds_and_bosses_flame/core/rules/tag_dictionary.dart';

class _CustomTestEventA extends RuleEvent {
  const _CustomTestEventA({required super.tick});
}

class _CustomTestEventB extends RuleEvent {
  const _CustomTestEventB({required super.tick});
}

void main() {
  group('M4: TagCondition & TagDictionary', () {
    test('requireAll matches only when all required tags exist', () {
      const cond = TagCondition.requireAll({'airborne', 'magic'});
      expect(cond.matches({'airborne', 'magic', 'speed_boost'}), isTrue);
      expect(cond.matches({'airborne'}), isFalse);
      expect(cond.matches({'magic'}), isFalse);
    });

    test('requireAny matches when at least one tag exists', () {
      const cond = TagCondition.requireAny({'spiked', 'pit'});
      expect(cond.matches({'spiked'}), isTrue);
      expect(cond.matches({'pit'}), isTrue);
      expect(cond.matches({'water'}), isFalse);
    });

    test('forbidAll matches only when none of forbidden tags exist', () {
      const cond = TagCondition.forbidAll({'airborne'});
      expect(cond.matches({'falling', 'ground'}), isTrue);
      expect(cond.matches({'falling', 'airborne'}), isFalse);
    });

    test('composite condition combines require and forbid clauses', () {
      const cond = TagCondition.composite(
        require: {'pit'},
        forbid: {'airborne'},
      );

      // In a pit and not airborne -> matches!
      expect(cond.matches({'pit'}), isTrue);
      // In a pit but airborne (e.g. Fly spell) -> does NOT fall!
      expect(cond.matches({'pit', 'airborne'}), isFalse);
      // Not in a pit -> does NOT match
      expect(cond.matches({'ground'}), isFalse);
    });

    test('tag dictionary validates known tags', () {
      final dict = TagDictionary.defaultDictionary();
      expect(dict.isValid('airborne'), isTrue);
      expect(dict.isValid('unknown_custom_tag'), isFalse);

      dict.registerTag('unknown_custom_tag');
      expect(dict.isValid('unknown_custom_tag'), isTrue);
    });
  });

  group('M4: RuleEngine & Conflict Detection', () {
    test('rules execute strictly in ascending priority order', () {
      final engine = RuleEngine();
      final executionOrder = <String>[];

      final ruleLate = Rule(
        id: 'R-030',
        priority: 30,
        onEventType: _CustomTestEventA,
        when: const TagCondition.always(),
        then: (_) => executionOrder.add('R-030'),
      );

      final ruleEarly = Rule(
        id: 'R-010',
        priority: 10,
        onEventType: _CustomTestEventA,
        when: const TagCondition.always(),
        then: (_) => executionOrder.add('R-010'),
      );

      final ruleMiddle = Rule(
        id: 'R-020',
        priority: 20,
        onEventType: _CustomTestEventA,
        when: const TagCondition.always(),
        then: (_) => executionOrder.add('R-020'),
      );

      // Register out of order
      engine.registerRules([ruleLate, ruleEarly, ruleMiddle]);

      final event = const _CustomTestEventA(tick: 1);
      final context = RuleContext(
        event: event,
        activeTags: const {},
        statusTracker: StatusTracker(),
        eventBus: RuleEventBus(),
      );

      final executed = engine.dispatch(event, context);
      expect(executed, equals(3));
      expect(executionOrder, equals(['R-010', 'R-020', 'R-030']));
    });

    test(
      'duplicate priority on the same event type throws RuleConflictException',
      () {
        final engine = RuleEngine();

        final ruleA = Rule(
          id: 'R-DUP-1',
          priority: 15,
          onEventType: _CustomTestEventA,
          when: const TagCondition.always(),
          then: (_) {},
        );

        final ruleB = Rule(
          id: 'R-DUP-2',
          priority: 15,
          onEventType: _CustomTestEventA,
          when: const TagCondition.always(),
          then: (_) {},
        );

        engine.registerRule(ruleA);

        expect(
          () => engine.registerRule(ruleB),
          throwsA(isA<RuleConflictException>()),
        );
      },
    );

    test('identical priority on DIFFERENT event types does not collide', () {
      final engine = RuleEngine();

      final ruleA = Rule(
        id: 'R-A',
        priority: 10,
        onEventType: _CustomTestEventA,
        when: const TagCondition.always(),
        then: (_) {},
      );

      final ruleB = Rule(
        id: 'R-B',
        priority: 10,
        onEventType: _CustomTestEventB,
        when: const TagCondition.always(),
        then: (_) {},
      );

      expect(() => engine.registerRules([ruleA, ruleB]), returnsNormally);
      expect(engine.rules.length, equals(2));
    });

    test('rule only fires when its tag condition matches', () {
      final engine = RuleEngine();
      var fired = false;

      final pitRule = Rule(
        id: 'R-PIT',
        priority: 10,
        onEventType: _CustomTestEventA,
        when: const TagCondition.composite(
          require: {'pit'},
          forbid: {'airborne'},
        ),
        then: (_) => fired = true,
      );

      engine.registerRule(pitRule);

      final event = const _CustomTestEventA(tick: 1);
      final tracker = StatusTracker();
      final bus = RuleEventBus();

      // Case 1: airborne entity in pit -> should NOT fire
      engine.dispatch(
        event,
        RuleContext(
          event: event,
          activeTags: const {'pit', 'airborne'},
          statusTracker: tracker,
          eventBus: bus,
        ),
      );
      expect(fired, isFalse);

      // Case 2: non-airborne entity in pit -> FIRES!
      engine.dispatch(
        event,
        RuleContext(
          event: event,
          activeTags: const {'pit'},
          statusTracker: tracker,
          eventBus: bus,
        ),
      );
      expect(fired, isTrue);
    });
  });
}
