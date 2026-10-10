import 'package:flutter_test/flutter_test.dart';

import 'package:builds_and_bosses_flame/core/rules/event_bus.dart';
import 'package:builds_and_bosses_flame/core/rules/status_tracker.dart';

class _CascadingTestEvent extends RuleEvent {
  final int depthRemaining;
  const _CascadingTestEvent({
    required super.tick,
    required this.depthRemaining,
  });
}

void main() {
  group('M3: Status Lifecycle & Refresh', () {
    test('status applies successfully and sets active status', () {
      final tracker = StatusTracker();
      final status = const Status(
        id: 'haste',
        holderId: 'player_1',
        sourceId: 'wizard_spell',
        startTick: 100,
        durationTicks: 600, // 10 seconds at 60Hz
        tags: {'speed_boost', 'magic'},
      );

      final event = tracker.applyStatus(status, 100);
      expect(event.isRefreshed, isFalse);
      expect(event.status.id, equals('haste'));

      final active = tracker.activeStatusesFor('player_1');
      expect(active.length, equals(1));
      expect(active.first.id, equals('haste'));
      expect(tracker.hasTag('player_1', 'speed_boost'), isTrue);
      expect(tracker.hasTag('player_1', 'poison'), isFalse);
      expect(
        tracker.activeTagsFor('player_1'),
        containsAll(['speed_boost', 'magic']),
      );
    });

    test('re-application does not stack; startTick is refreshed', () {
      final tracker = StatusTracker();
      final initial = const Status(
        id: 'cats_grace',
        holderId: 'rogue',
        sourceId: 'cleric_buff',
        startTick: 0,
        durationTicks: 300,
        tags: {'safe_fall'},
      );

      tracker.applyStatus(initial, 0);

      // Re-apply at tick 200 from a different source
      final reapply = const Status(
        id: 'cats_grace',
        holderId: 'rogue',
        sourceId: 'potion',
        startTick: 200,
        durationTicks: 300,
        tags: {'safe_fall'},
      );

      final event = tracker.applyStatus(reapply, 200);
      expect(event.isRefreshed, isTrue);

      final active = tracker.activeStatusesFor('rogue');
      expect(active.length, equals(1)); // NO STACKING
      expect(active.first.startTick, equals(200)); // Refreshed startTick
    });

    test('status expires at exact tick boundary and emits expiry event', () {
      final tracker = StatusTracker();
      final status = const Status(
        id: 'shield',
        holderId: 'fighter',
        sourceId: 'spell',
        startTick: 50,
        durationTicks: 100, // Expires at tick 150
      );

      tracker.applyStatus(status, 50);

      // Tick 149: still active
      final expiredAt149 = tracker.updateTick(149);
      expect(expiredAt149, isEmpty);
      expect(tracker.activeStatusesFor('fighter').length, equals(1));

      // Tick 150: expires
      final expiredAt150 = tracker.updateTick(150);
      expect(expiredAt150.length, equals(1));
      expect(expiredAt150.first.status.id, equals('shield'));
      expect(tracker.activeStatusesFor('fighter'), isEmpty);
      expect(tracker.hasTag('fighter', 'any'), isFalse);
    });

    test('permanent status with duration 0 does not expire automatically', () {
      final tracker = StatusTracker();
      final perm = const Status(
        id: 'curse',
        holderId: 'boss',
        sourceId: 'altar',
        startTick: 0,
        durationTicks: 0,
      );

      tracker.applyStatus(perm, 0);
      final expired = tracker.updateTick(100000);
      expect(expired, isEmpty);
      expect(tracker.activeStatusesFor('boss').length, equals(1));

      // Explicit removal works
      final removed = tracker.removeStatus('boss', 'curse');
      expect(removed, isNotNull);
      expect(tracker.activeStatusesFor('boss'), isEmpty);
    });
  });

  group('M3: RuleEventBus & Chain Depth Protection', () {
    test('event bus synchronously dispatches events to subscribers', () {
      final bus = RuleEventBus();
      final received = <String>[];

      bus.subscribe<StatusAppliedEvent>((e) {
        received.add('applied:${e.status.id}');
      });
      bus.subscribe<StatusExpiredEvent>((e) {
        received.add('expired:${e.status.id}');
      });

      const sampleStatus = Status(
        id: 'invisibility',
        holderId: 'hero',
        sourceId: 'ring',
        startTick: 10,
        durationTicks: 60,
      );

      bus.publish(
        const StatusAppliedEvent(
          status: sampleStatus,
          tick: 10,
          isRefreshed: false,
        ),
      );
      bus.publish(const StatusExpiredEvent(status: sampleStatus, tick: 70));

      expect(
        received,
        equals(['applied:invisibility', 'expired:invisibility']),
      );
    });

    test('cascading events within maxChainDepth execute cleanly', () {
      final bus = RuleEventBus(maxChainDepth: 5);
      var cascadeCount = 0;

      bus.subscribe<_CascadingTestEvent>((e) {
        cascadeCount++;
        if (e.depthRemaining > 0) {
          bus.publish(
            _CascadingTestEvent(
              tick: e.tick + 1,
              depthRemaining: e.depthRemaining - 1,
            ),
          );
        }
      });

      // Chain of depth 4 with limit 5 should succeed
      bus.publish(const _CascadingTestEvent(tick: 0, depthRemaining: 3));
      expect(cascadeCount, equals(4));
      expect(bus.currentDepth, equals(0));
    });

    test('cascading events exceeding maxChainDepth throw StateError', () {
      final bus = RuleEventBus(maxChainDepth: 3);

      bus.subscribe<_CascadingTestEvent>((e) {
        if (e.depthRemaining > 0) {
          bus.publish(
            _CascadingTestEvent(
              tick: e.tick + 1,
              depthRemaining: e.depthRemaining - 1,
            ),
          );
        }
      });

      // Chain of depth 5 with limit 3 must throw StateError
      expect(
        () =>
            bus.publish(const _CascadingTestEvent(tick: 0, depthRemaining: 4)),
        throwsStateError,
      );
      // Recursion unwinds cleanly
      expect(bus.currentDepth, equals(0));
    });
  });
}
