import 'package:flutter_test/flutter_test.dart';

import 'package:builds_and_bosses_flame/core/physics/displacement_resolver.dart';
import 'package:builds_and_bosses_flame/core/physics/fixed_units.dart';
import 'package:builds_and_bosses_flame/core/rules/gravity_zone.dart';
import 'package:builds_and_bosses_flame/core/rules/pit_fill_tracker.dart';

void main() {
  const resolver = DisplacementResolver();

  group('M6: Displacement & Shove Golden Table (EMERGENT 3.4)', () {
    test('Row 1: STR 16 vs goblin 60 lb, margin +10', () {
      final outcome = resolver.resolveShove(
        targetId: 'goblin',
        pusherStrength: 16, // force = 480 lb
        targetWeightLb: 60,
        pusherContestRoll: 20,
        targetContestRoll: 10, // margin = +10
      );

      // weightFactor = 1 - 60/480 = 0.875 (875 milli)
      expect(outcome.weightFactor.raw, equals(875));
      expect(outcome.contestScale.raw, equals(1000));
      // 3.0 * 0.875 * 1.0 = 2.625 tiles (2625 milli)
      expect(outcome.distanceTiles.raw, equals(2625));
      expect(outcome.didMove, isTrue);
      expect(outcome.durationTicks, equals(12));
    });

    test('Row 2: STR 16 vs human 180 lb, margin +10', () {
      final outcome = resolver.resolveShove(
        targetId: 'human',
        pusherStrength: 16,
        targetWeightLb: 180,
        pusherContestRoll: 25,
        targetContestRoll: 15, // margin = +10
      );

      // weightFactor = 1 - 180/480 = 0.625 (625 milli)
      expect(outcome.weightFactor.raw, equals(625));
      expect(outcome.contestScale.raw, equals(1000));
      // 3.0 * 0.625 * 1.0 = 1.875 tiles (1875 milli)
      expect(outcome.distanceTiles.raw, equals(1875));
      expect(outcome.didMove, isTrue);
    });

    test('Row 3: STR 16 vs human 180 lb, margin 0 (tie)', () {
      final outcome = resolver.resolveShove(
        targetId: 'human',
        pusherStrength: 16,
        targetWeightLb: 180,
        pusherContestRoll: 15,
        targetContestRoll: 15, // margin = 0
      );

      // contestScale = (0 + 10) / 20 = 0.5 (500 milli)
      expect(outcome.contestScale.raw, equals(500));
      // 3.0 * 0.625 * 0.5 = 0.937 tiles (937 milli)
      expect(outcome.distanceTiles.raw, equals(937));
      expect(outcome.didMove, isTrue);
    });

    test(
      'Row 4: STR 20 vs ogre 650 lb -> weight exceeds push limit -> 0 distance',
      () {
        final outcome = resolver.resolveShove(
          targetId: 'ogre',
          pusherStrength: 20, // force = 600 lb
          targetWeightLb: 650, // weight > force!
          pusherContestRoll: 30,
          targetContestRoll: 5,
        );

        // Immune to standard shove!
        expect(outcome.weightFactor.raw, equals(0));
        expect(outcome.distanceTiles.raw, equals(0));
        expect(outcome.didMove, isFalse);
      },
    );

    test(
      'Row 5: Powerful spell knockback 1500 lb vs ogre 650 lb, margin +10',
      () {
        final outcome = resolver.resolve(
          const DisplacementRequest(
            targetId: 'ogre',
            targetWeightLb: 650,
            forceLb: 1500,
            contestMargin: 10,
          ),
        );

        // weightFactor = (1000 - 650*1000~/1500) = 1000 - 433 = 567
        expect(outcome.weightFactor.raw, equals(567));
        expect(outcome.contestScale.raw, equals(1000));
        // 3000 * 567 / 1000 = 1701 milli (~1.70 tiles)
        expect(outcome.distanceTiles.raw, equals(1701));
        expect(outcome.didMove, isTrue);
      },
    );

    test(
      'minMove threshold zeroes out trivial displacements below 0.25 tiles',
      () {
        // Extremely heavy target near force limit yielding distance < 250 milli
        final outcome = resolver.resolve(
          const DisplacementRequest(
            targetId: 'golem',
            targetWeightLb: 950,
            forceLb: 1000, // weightFactor = 50 milli (0.05)
            contestMargin: -5, // scale = 250 milli (0.25)
          ),
        );

        // Raw distance would be: 3000 * 0.05 * 0.25 = 37 milli (< 250 minMove)
        expect(outcome.distanceTiles.raw, equals(0));
        expect(outcome.didMove, isFalse);
      },
    );
  });

  group('M6: Anchored Gravity Zones & Pit Fill Tracker', () {
    test('gravity zone modifies regional gravity vector and emits events', () {
      final registry = GravityZoneRegistry();
      const zone = GravityZone(
        id: 'reverse_gravity_chamber',
        minXMilli: 0,
        minYMilli: 0,
        maxXMilli: 10000,
        maxYMilli: 5000,
        direction: GravityDirection.inverted,
        gravityFactor: Fixed(-1000),
      );

      registry.registerZone(zone);

      // Inside zone
      expect(
        registry.directionAt(5000, 2500),
        equals(GravityDirection.inverted),
      );
      expect(registry.factorAt(5000, 2500).raw, equals(-1000));

      // Outside zone
      expect(
        registry.directionAt(15000, 2500),
        equals(GravityDirection.normal),
      );
      expect(registry.factorAt(15000, 2500).raw, equals(1000));
    });

    test('pit fills progressively and transforms into solid platform upon completion', () {
      final tracker = PitFillTracker();
      final pit = PitCell(
        id: 'pit_4_12',
        tileX: 4,
        tileY: 12,
        capacityMilli: 1000, // 1 tile volume capacity
      );

      tracker.registerPit(pit);
      expect(tracker.isOpenPit(4, 12), isTrue);

      // Deposit 1: half block (500 milli)
      final event1 = tracker.deposit(
        pitId: 'pit_4_12',
        volumeMilli: 500,
        tick: 10,
      );
      expect(event1, isNull);
      expect(tracker.isOpenPit(4, 12), isTrue);

      // Deposit 2: another half block (500 milli) -> fills!
      final event2 = tracker.deposit(
        pitId: 'pit_4_12',
        volumeMilli: 500,
        tick: 20,
      );
      expect(event2, isNotNull);
      expect(event2!.pitId, equals('pit_4_12'));
      expect(tracker.isOpenPit(4, 12), isFalse); // Closed, solid platform now!
    });
  });

  group('Universal PhysicalContestResolver Tests', () {
    const contest = PhysicalContestResolver();

    test('Gaseous form yields passThrough with zero displacement', () {
      final outcome = contest.resolve(
        const PhysicalContestRequest(
          moverStr: 20,
          targetStr: 20,
          moverVelocity: 180.0,
          isGaseous: true,
        ),
      );
      expect(outcome.result, equals(PhysicalContestResult.passThrough));
      expect(outcome.isBodyBlocked, isFalse);
      expect(outcome.canShoveTarget, isFalse);
      expect(outcome.targetDisplacement, equals(0.0));
      expect(outcome.moverDisplacement, equals(0.0));
    });

    test(
      'Head-on equal STR 16 produces standoff with halted moverSpeedFactor',
      () {
        final outcome = contest.resolve(
          const PhysicalContestRequest(
            moverStr: 16,
            targetStr: 16,
            moverVelocity: -180.0,
            targetVelocity: 48.0,
          ),
        );
        expect(outcome.result, equals(PhysicalContestResult.standoff));
        expect(outcome.moverSpeedFactor, equals(0.0));
        expect(outcome.isBodyBlocked, isTrue);
        expect(outcome.canShoveTarget, isFalse);
      },
    );

    test('Head-on STR 20 overpowers STR 16 and produces targetDisplacement backwards', () {
      final outcome = contest.resolve(
        const PhysicalContestRequest(
          moverStr: 20,
          targetStr: 16,
          moverVelocity: -180.0,
          targetVelocity: 48.0,
          dt: 0.1,
        ),
      );
      expect(outcome.result, equals(PhysicalContestResult.moverWins));
      expect(outcome.canShoveTarget, isTrue);
      expect(outcome.isBodyBlocked, isTrue);
      // Mover is moving left (-180), so target displacement is negative (shoved left)
      expect(outcome.targetDisplacement, lessThan(0.0));
    });

    test('Head-on STR 10 vs 16 yields targetWins, pusher displaced back', () {
      final outcome = contest.resolve(
        const PhysicalContestRequest(
          moverStr: 10,
          targetStr: 16,
          moverVelocity: -180.0,
          targetVelocity: 48.0,
          dt: 0.1,
        ),
      );
      expect(outcome.result, equals(PhysicalContestResult.targetWins));
      expect(outcome.canShoveTarget, isFalse);
      expect(outcome.isBodyBlocked, isTrue);
      expect(outcome.moverDisplacement, greaterThan(0.0));
    });

    test(
      'Unidirectional: STR >= 16 shoves standard enemy, STR < 16 body blocks',
      () {
        final weak = contest.resolve(
          const PhysicalContestRequest(
            moverStr: 10,
            targetStr: 10,
            moverVelocity: 180.0,
            targetVelocity: 0.0,
            dt: 0.1,
          ),
        );
        expect(weak.canShoveTarget, isFalse);
        expect(weak.targetDisplacement, equals(0.0));
        expect(weak.isBodyBlocked, isTrue);

        final strong = contest.resolve(
          const PhysicalContestRequest(
            moverStr: 16,
            targetStr: 10,
            moverVelocity: 180.0,
            targetVelocity: 0.0,
            dt: 0.1,
          ),
        );
        expect(strong.canShoveTarget, isTrue);
        expect(strong.targetDisplacement, greaterThan(0.0));
        expect(strong.isBodyBlocked, isTrue);
      },
    );

    test('Rideable entity requires moverStr > targetStr to shove', () {
      final equalMover = contest.resolve(
        const PhysicalContestRequest(
          moverStr: 16,
          targetStr: 16,
          moverVelocity: 180.0,
          targetVelocity: 0.0,
          isRideable: true,
        ),
      );
      expect(equalMover.canShoveTarget, isFalse);

      final apexMover = contest.resolve(
        const PhysicalContestRequest(
          moverStr: 20,
          targetStr: 16,
          moverVelocity: 180.0,
          targetVelocity: 0.0,
          isRideable: true,
          dt: 0.1,
        ),
      );
      expect(apexMover.canShoveTarget, isTrue);
      expect(apexMover.targetDisplacement, greaterThan(0.0));
    });

    test('Passive STR 20 entity creates drag, reducing moverSpeedFactor', () {
      final vsWeak = contest.resolve(
        const PhysicalContestRequest(
          moverStr: 16,
          targetStr: 10,
          moverVelocity: 48.0,
          targetVelocity: 0.0,
        ),
      );
      final vsStrong = contest.resolve(
        const PhysicalContestRequest(
          moverStr: 16,
          targetStr: 20,
          moverVelocity: 48.0,
          targetVelocity: 0.0,
        ),
      );
      expect(vsWeak.moverSpeedFactor, equals(1.0));
      expect(vsStrong.moverSpeedFactor, lessThan(1.0));
    });
  });
}
