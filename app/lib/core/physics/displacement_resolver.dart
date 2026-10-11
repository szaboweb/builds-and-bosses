import 'dart:math';

import 'fixed_units.dart';

/// Configuration for shove and knockback displacement calculations.
class DisplacementConfig {
  /// Base displacement distance in tiles (default 3 tiles = 3000 milli-units).
  final Fixed baseDistanceTiles;

  /// Range for scaling contest roll margins (default 10).
  final int marginRange;

  /// Minimum movement threshold; distances below this become 0 (default 0.25 tiles = 250 milli).
  final Fixed minMoveTiles;

  /// Duration in 60 Hz simulation ticks for displacement animation (default 12 ticks = 0.2s).
  final int displaceTicks;

  const DisplacementConfig({
    this.baseDistanceTiles = const Fixed(3000),
    this.marginRange = 10,
    this.minMoveTiles = const Fixed(250),
    this.displaceTicks = 12,
  });
}

/// Request parameters for resolving a shove or knockback displacement.
class DisplacementRequest {
  final String targetId;
  final int targetWeightLb;
  final int forceLb;
  final int contestMargin;
  final Fixed? customBaseDistance;
  final int tick;

  const DisplacementRequest({
    required this.targetId,
    required this.targetWeightLb,
    required this.forceLb,
    required this.contestMargin,
    this.customBaseDistance,
    this.tick = 0,
  });
}

/// Outcome of resolving a displacement contest.
class DisplacementOutcome {
  final Fixed weightFactor;
  final Fixed contestScale;
  final Fixed distanceTiles;
  final int durationTicks;
  final bool didMove;

  const DisplacementOutcome({
    required this.weightFactor,
    required this.contestScale,
    required this.distanceTiles,
    required this.durationTicks,
    required this.didMove,
  });
}

/// Deterministic resolver for shove and knockback contests according to EMERGENT_RULES_SPEC 3.
class DisplacementResolver {
  final DisplacementConfig config;

  const DisplacementResolver({this.config = const DisplacementConfig()});

  /// Resolves a shove action using the pusher's effective strength score.
  /// Force is calculated as 30 * pusherStrength (lb).
  DisplacementOutcome resolveShove({
    required String targetId,
    required int pusherStrength,
    required int targetWeightLb,
    required int pusherContestRoll,
    required int targetContestRoll,
    int tick = 0,
  }) {
    final forceLb = 30 * pusherStrength;
    final margin = pusherContestRoll - targetContestRoll;

    return resolve(
      DisplacementRequest(
        targetId: targetId,
        targetWeightLb: targetWeightLb,
        forceLb: forceLb,
        contestMargin: margin,
        tick: tick,
      ),
    );
  }

  /// Resolves displacement from a [DisplacementRequest] using deterministic fixed-point math:
  /// - weightFactor = clamp(1 - weight / forceLb, 0, 1)
  /// - margin = pusher_score - target_score
  /// - scale = clamp((margin + R) / (2 * R), 0, 1)
  /// - distance = baseDistance * weightFactor * scale
  /// - if distance < minMove -> distance = 0
  DisplacementOutcome resolve(DisplacementRequest request) {
    // 1. Weight factor
    if (request.forceLb <= 0 || request.targetWeightLb >= request.forceLb) {
      return const DisplacementOutcome(
        weightFactor: Fixed.zero,
        contestScale: Fixed.zero,
        distanceTiles: Fixed.zero,
        durationTicks: 0,
        didMove: false,
      );
    }

    // weightFactor = (1000 - (weight * 1000 ~/ force)) clamp(0, 1000)
    final weightRatioMilli = (request.targetWeightLb * 1000) ~/ request.forceLb;
    final weightFactorMilli = (1000 - weightRatioMilli).clamp(0, 1000);
    final weightFactor = Fixed(weightFactorMilli);

    // 2. Contest scale
    final r = config.marginRange;
    final numerator = request.contestMargin + r;
    final denominator = 2 * r;
    final scaleMilli = ((numerator * 1000) ~/ denominator).clamp(0, 1000);
    final contestScale = Fixed(scaleMilli);

    // 3. Distance calculation
    final base = request.customBaseDistance ?? config.baseDistanceTiles;
    final distanceMilli =
        (base.raw * weightFactorMilli ~/ 1000 * scaleMilli) ~/ 1000;
    var finalDistance = Fixed(distanceMilli);

    // 4. Minimum movement threshold
    if (finalDistance.isLessThan(config.minMoveTiles)) {
      finalDistance = Fixed.zero;
    }

    final didMove = finalDistance.raw > 0;
    final duration = didMove ? config.displaceTicks : 0;

    return DisplacementOutcome(
      weightFactor: weightFactor,
      contestScale: contestScale,
      distanceTiles: finalDistance,
      durationTicks: duration,
      didMove: didMove,
    );
  }
}

/// The qualitative contest result of physical collision/shove.
enum PhysicalContestResult {
  /// Mover overpowers the target and pushes/shoves it.
  moverWins,

  /// Target overpowers the mover and pushes/shoves it.
  targetWins,

  /// Both entities have equal strength and halt each other (deadlock / standoff).
  standoff,

  /// No collision or resistance (e.g. gaseous form or clearance).
  passThrough,
}

/// Request parameters for evaluating a physical strength contest.
class PhysicalContestRequest {
  final int moverStr;
  final int targetStr;
  final double moverVelocity;
  final double targetVelocity;
  final bool isRideable;
  final bool isGaseous;
  final double dt;

  const PhysicalContestRequest({
    required this.moverStr,
    required this.targetStr,
    required this.moverVelocity,
    this.targetVelocity = 0.0,
    this.isRideable = false,
    this.isGaseous = false,
    this.dt = 0.016,
  });
}

/// Outcome of evaluating a physical strength contest between two entities.
class PhysicalContestOutcome {
  final PhysicalContestResult result;
  final double targetDisplacement;
  final double moverDisplacement;
  final double moverSpeedFactor;
  final bool canShoveTarget;
  final bool isBodyBlocked;

  const PhysicalContestOutcome({
    required this.result,
    required this.targetDisplacement,
    required this.moverDisplacement,
    required this.moverSpeedFactor,
    required this.canShoveTarget,
    required this.isBodyBlocked,
  });

  static const PhysicalContestOutcome passThrough = PhysicalContestOutcome(
    result: PhysicalContestResult.passThrough,
    targetDisplacement: 0.0,
    moverDisplacement: 0.0,
    moverSpeedFactor: 1.0,
    canShoveTarget: false,
    isBodyBlocked: false,
  );
}

/// Headless, deterministic resolver evaluating physical body contact,
/// Strength contests, drag resistance, and shoves between any two entities.
class PhysicalContestResolver {
  const PhysicalContestResolver();

  PhysicalContestOutcome resolve(PhysicalContestRequest request) {
    if (request.isGaseous) {
      return PhysicalContestOutcome.passThrough;
    }

    final moverDir = request.moverVelocity > 0
        ? 1.0
        : (request.moverVelocity < 0 ? -1.0 : 0.0);
    final targetDir = request.targetVelocity > 0
        ? 1.0
        : (request.targetVelocity < 0 ? -1.0 : 0.0);

    // Check if moving head-on towards each other
    final isHeadOn =
        moverDir != 0 && targetDir != 0 && (moverDir * targetDir < 0);

    if (isHeadOn) {
      return _resolveHeadOnContest(request, moverDir);
    }

    return _resolveUnidirectionalContest(request, moverDir);
  }

  PhysicalContestOutcome _resolveHeadOnContest(
    PhysicalContestRequest request,
    double moverDir,
  ) {
    if (request.moverStr > request.targetStr) {
      final diff = request.moverStr - request.targetStr;
      final speed =
          request.moverVelocity.abs() * 0.4 * (diff / 4.0).clamp(0.25, 1.0);
      final shoveDist = speed * request.dt * moverDir;

      return PhysicalContestOutcome(
        result: PhysicalContestResult.moverWins,
        targetDisplacement: shoveDist,
        moverDisplacement: 0.0,
        moverSpeedFactor: 1.0,
        canShoveTarget: true,
        isBodyBlocked: true,
      );
    }

    if (request.moverStr == request.targetStr) {
      return const PhysicalContestOutcome(
        result: PhysicalContestResult.standoff,
        targetDisplacement: 0.0,
        moverDisplacement: 0.0,
        moverSpeedFactor: 0.0,
        canShoveTarget: false,
        isBodyBlocked: true,
      );
    }

    // Target wins
    final resistance = (request.moverStr / request.targetStr).clamp(0.2, 0.75);
    final targetEffectiveSpeed =
        request.targetVelocity.abs() * (1.0 - resistance);
    final moverPushedDist =
        targetEffectiveSpeed *
        request.dt *
        (request.targetVelocity > 0 ? 1.0 : -1.0);

    return PhysicalContestOutcome(
      result: PhysicalContestResult.targetWins,
      targetDisplacement: 0.0,
      moverDisplacement: moverPushedDist,
      moverSpeedFactor: 1.0 - resistance,
      canShoveTarget: false,
      isBodyBlocked: true,
    );
  }

  PhysicalContestOutcome _resolveUnidirectionalContest(
    PhysicalContestRequest request,
    double moverDir,
  ) {
    final canShove =
        request.moverStr >= 16 &&
        (!request.isRideable || request.moverStr > request.targetStr);

    var moverSpeedFactor = 1.0;
    if (request.targetStr >= 16 && request.targetVelocity.abs() <= 0.1) {
      final drag = ((request.targetStr - 10) * 0.04).clamp(0.1, 0.45);
      moverSpeedFactor = 1.0 - drag;
    }

    final targetDisplacement = canShove
        ? (request.moverVelocity.abs() * 0.8 * request.dt * moverDir)
        : 0.0;

    return PhysicalContestOutcome(
      result: canShove
          ? PhysicalContestResult.moverWins
          : PhysicalContestResult.standoff,
      targetDisplacement: targetDisplacement,
      moverDisplacement: 0.0,
      moverSpeedFactor: moverSpeedFactor,
      canShoveTarget: canShove,
      isBodyBlocked: true,
    );
  }
}
