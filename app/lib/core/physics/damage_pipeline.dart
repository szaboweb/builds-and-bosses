import 'dart:math';

import 'derived_stats.dart';
import 'fixed_units.dart';

/// The category of physical damage evaluated by the physics pipeline.
enum DamageCategory { fall, impact, crush }

/// Obstacle properties influencing impact kinetic absorption.
class ObstacleAbsorptionInfo {
  final bool isFixed;
  final int weightLb;
  final bool isFragile;
  final int breakThreshold;
  final int fragileAbsorbHp;

  const ObstacleAbsorptionInfo({
    this.isFixed = true,
    this.weightLb = 0,
    this.isFragile = false,
    this.breakThreshold = 0,
    this.fragileAbsorbHp = 0,
  });

  static const ObstacleAbsorptionInfo solidWall = ObstacleAbsorptionInfo(
    isFixed: true,
  );
}

/// Configuration settings for physical fall and impact damage.
class DamagePipelineConfig {
  final int safeHeightTiles;
  final int hpPerTile;
  final int maxEquivalentHeight;

  const DamagePipelineConfig({
    this.safeHeightTiles = 2,
    this.hpPerTile = 3,
    this.maxEquivalentHeight = 20,
  });
}

/// Step-by-step breakdown of damage reduction through the pipeline layers.
class DamageBreakdown {
  final int rawDamage;
  final int afterAbsorption;
  final int afterDexResilience;
  final int afterConReduction;
  final int afterResistanceMultiplier;

  const DamageBreakdown({
    required this.rawDamage,
    required this.afterAbsorption,
    required this.afterDexResilience,
    required this.afterConReduction,
    required this.afterResistanceMultiplier,
  });
}

/// Result of evaluating a damage event through the 6-step damage pipeline.
class DamagePipelineResult {
  final DamageBreakdown breakdown;
  final int tempHpAbsorbed;
  final int finalHpDamage;
  final int remainingTempHp;
  final int remainingHp;

  const DamagePipelineResult({
    required this.breakdown,
    required this.tempHpAbsorbed,
    required this.finalHpDamage,
    required this.remainingTempHp,
    required this.remainingHp,
  });

  int get rawDamage => breakdown.rawDamage;
  int get afterAbsorption => breakdown.afterAbsorption;
  int get afterDexResilience => breakdown.afterDexResilience;
  int get afterConReduction => breakdown.afterConReduction;
  int get afterResistanceMultiplier => breakdown.afterResistanceMultiplier;
}

/// The deterministic 6-step damage pipeline for fall, impact, and crush damage.
class DamagePipeline {
  final DamagePipelineConfig config;

  const DamagePipeline({this.config = const DamagePipelineConfig()});

  /// Evaluates damage strictly according to PHYSICS_HANDOFF 2.2 pipeline steps:
  /// 1. Raw damage from equivalent height
  /// 2. Obstacle kinetic absorption (impact only)
  /// 3. DEX resilience ratio reduction (fall only)
  /// 4. CON flat damage reduction (impact and crush only, minimum 1)
  /// 5. Resistance multiplier (e.g. Stoneskin ×0.5)
  /// 6. Temporary HP, then HP deduction
  DamagePipelineResult resolve({
    required DamageCategory category,
    required int equivalentHeightTiles,
    required DerivedPhysicsStats derivedStats,
    required int currentHp,
    int currentTempHp = 0,
    bool hasResistance = false,
    ObstacleAbsorptionInfo obstacle = ObstacleAbsorptionInfo.solidWall,
  }) {
    // Step 1: Raw damage
    final clampedHEq = equivalentHeightTiles.clamp(
      0,
      config.maxEquivalentHeight,
    );
    final rawDamage =
        max(0, clampedHEq - config.safeHeightTiles) * config.hpPerTile;
    var currentDamage = rawDamage;

    // Step 2: Obstacle kinetic absorption (impact only)
    if (category == DamageCategory.impact && currentDamage > 0) {
      currentDamage = _applyObstacleAbsorption(
        currentDamage,
        clampedHEq,
        derivedStats,
        obstacle,
      );
    }
    final afterAbsorption = currentDamage;

    // Step 3: DEX resilience ratio reduction (fall only)
    if (category == DamageCategory.fall && currentDamage > 0) {
      final ratioMilli = derivedStats.fallResilienceRatio.raw;
      currentDamage = (currentDamage * (1000 - ratioMilli)) ~/ 1000;
    }
    final afterDexResilience = currentDamage;

    // Step 4: CON flat reduction (impact and crush only, minimum 1)
    if ((category == DamageCategory.impact ||
            category == DamageCategory.crush) &&
        currentDamage > 0) {
      final reduction = derivedStats.flatDamageReduction.raw ~/ 1000;
      currentDamage = max(1, currentDamage - reduction);
    }
    final afterConReduction = currentDamage;

    // Step 5: Resistance multiplier (e.g. Stoneskin x0.5)
    if (hasResistance && currentDamage > 0) {
      currentDamage = currentDamage ~/ 2;
    }
    final afterResistanceMultiplier = currentDamage;

    // Step 6: Temporary HP deduction, then HP deduction
    final tempAbsorbed = min(currentTempHp, currentDamage);
    final remainingTempHp = currentTempHp - tempAbsorbed;
    final finalHpDamage = currentDamage - tempAbsorbed;
    final remainingHp = max(0, currentHp - finalHpDamage);

    return DamagePipelineResult(
      breakdown: DamageBreakdown(
        rawDamage: rawDamage,
        afterAbsorption: afterAbsorption,
        afterDexResilience: afterDexResilience,
        afterConReduction: afterConReduction,
        afterResistanceMultiplier: afterResistanceMultiplier,
      ),
      tempHpAbsorbed: tempAbsorbed,
      finalHpDamage: finalHpDamage,
      remainingTempHp: remainingTempHp,
      remainingHp: remainingHp,
    );
  }

  int _applyObstacleAbsorption(
    int damage,
    int hEq,
    DerivedPhysicsStats stats,
    ObstacleAbsorptionInfo obstacle,
  ) {
    if (obstacle.isFragile && damage > obstacle.breakThreshold) {
      return max(0, damage - obstacle.fragileAbsorbHp);
    }

    if (!obstacle.isFixed) {
      // Limit = pushLimitLb * (1 + hEq / 4)
      final baseLimit = stats.pushLimitLb.raw ~/ 1000;
      final kFactorMilli = 1000 + (hEq * 1000) ~/ 4;
      final dynamicLimit = (baseLimit * kFactorMilli) ~/ 1000;

      if (dynamicLimit > 0 && obstacle.weightLb <= dynamicLimit) {
        // absorb = clamp(1 - weight / limit, 0, 0.8)
        final weightRatioMilli = (obstacle.weightLb * 1000) ~/ dynamicLimit;
        final absorbMilli = (1000 - weightRatioMilli).clamp(0, 800);
        final absorbedDamage = (damage * absorbMilli) ~/ 1000;
        return max(0, damage - absorbedDamage);
      }
    }

    return damage;
  }
}
