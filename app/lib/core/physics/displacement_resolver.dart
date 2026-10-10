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
