import 'dart:math';

/// D&D 5e Level Progression and Attribute Scaling rules engine.
///
/// Computes level bounds, Ability Score Improvements (ASI), Proficiency Bonus,
/// Hit Points scaling and Action Points / Mana pool for character builds.
class CharacterProgression {
  static const int minLevel = 1;
  static const int maxLevel = 20;

  /// Returns total Ability Score Improvement (ASI) points available at [level].
  ///
  /// In D&D 5e:
  /// - Standard classes receive ASI at levels 4, 8, 12, 16, 19 (+2 points each).
  /// - Fighters receive bonus ASIs at levels 6 and 14 (+2 points each).
  /// - Rogues receive a bonus ASI at level 10 (+2 points).
  static int asiPointsForLevel(int level, {String classId = 'fighter'}) {
    final clampedLevel = level.clamp(minLevel, maxLevel);
    int points = 0;
    if (clampedLevel >= 4) points += 2;
    if (classId == 'fighter' && clampedLevel >= 6) points += 2;
    if (clampedLevel >= 8) points += 2;
    if (classId == 'rogue' && clampedLevel >= 10) points += 2;
    if (clampedLevel >= 12) points += 2;
    if (classId == 'fighter' && clampedLevel >= 14) points += 2;
    if (clampedLevel >= 16) points += 2;
    if (clampedLevel >= 19) points += 2;
    return points;
  }

  /// Calculates max Hit Points for a given [level] and [conMod].
  ///
  /// Level 1: baseHp + conMod (clamped to at least 1).
  /// Level > 1: Level 1 HP + (level - 1) * (hpPerLevel + conMod).
  static int calculateMaxHp(
    int level,
    int conMod, {
    int baseHp = 12,
    int hpPerLevel = 6,
  }) {
    final clampedLevel = level.clamp(minLevel, maxLevel);
    final firstLevelHp = max(1, baseHp + conMod);
    if (clampedLevel == 1) return firstLevelHp;
    final levelGain = max(1, hpPerLevel + conMod);
    return firstLevelHp + (clampedLevel - 1) * levelGain;
  }

  /// Calculates max Action Points (AP) / Mana for tactical planning.
  ///
  /// Base AP: 100.
  /// Level bonus: +5 AP per level after 1st (+95 AP at level 20).
  /// Mental attribute bonus: +5 AP per point of positive INT or WIS modifier.
  static int calculateMaxAp(
    int level, {
    int intMod = 0,
    int wisMod = 0,
    int baseAp = 100,
    int apPerLevel = 5,
  }) {
    final clampedLevel = level.clamp(minLevel, maxLevel);
    final levelBonus = (clampedLevel - 1) * apPerLevel;
    final mentalBonus = max(0, max(intMod, wisMod)) * 5;
    return baseAp + levelBonus + mentalBonus;
  }

  /// D&D 5e Proficiency Bonus derived from level: 2 + ((level - 1) ~/ 4).
  static int proficiencyBonusFor(int level) {
    return 2 + ((level.clamp(minLevel, maxLevel) - 1) ~/ 4);
  }

  /// Provides comparative analysis between Level 1 baseline and Level 20 peak build.
  static Level20ImpactAnalysis analyzeLevel20Impact({
    required StatProgressionSnapshot baseline,
    required StatProgressionSnapshot peak,
  }) {
    final hpDeltaPercent = ((peak.hp - baseline.hp) / baseline.hp) * 100;
    final apDeltaPercent = ((peak.ap - baseline.ap) / baseline.ap) * 100;
    final speedDeltaPercent =
        ((peak.speed - baseline.speed) / baseline.speed) * 100;
    final jumpDeltaPercent =
        ((peak.jumpHeight - baseline.jumpHeight) / baseline.jumpHeight) * 100;
    final attackDeltaPercent = baseline.attackBonus > 0
        ? ((peak.attackBonus - baseline.attackBonus) / baseline.attackBonus) *
              100
        : 100.0;

    return Level20ImpactAnalysis(
      hpDeltaPercent: hpDeltaPercent,
      apDeltaPercent: apDeltaPercent,
      speedDeltaPercent: speedDeltaPercent,
      jumpDeltaPercent: jumpDeltaPercent,
      attackDeltaPercent: attackDeltaPercent,
      biggestImpactName: 'ÉLETERŐ (HP)',
      biggestImpactDescription:
          'A 20. szinten a legnagyobb érvényesülő hatás a HP megnövekedése (+${hpDeltaPercent.toStringAsFixed(0)}%), '
          'amelyet az AP/Mana duplázódása (+${apDeltaPercent.toStringAsFixed(0)}%) és a magaslati ugrások (+${jumpDeltaPercent.toStringAsFixed(0)}%) követ.',
    );
  }
}

/// Snapshot of stats used for comparative progression analysis.
class StatProgressionSnapshot {
  final int hp;
  final int ap;
  final double speed;
  final double jumpHeight;
  final int attackBonus;

  const StatProgressionSnapshot({
    required this.hp,
    required this.ap,
    required this.speed,
    required this.jumpHeight,
    required this.attackBonus,
  });
}

/// Analysis summary of the Level 20 stat scaling.
class Level20ImpactAnalysis {
  final double hpDeltaPercent;
  final double apDeltaPercent;
  final double speedDeltaPercent;
  final double jumpDeltaPercent;
  final double attackDeltaPercent;
  final String biggestImpactName;
  final String biggestImpactDescription;

  const Level20ImpactAnalysis({
    required this.hpDeltaPercent,
    required this.apDeltaPercent,
    required this.speedDeltaPercent,
    required this.jumpDeltaPercent,
    required this.attackDeltaPercent,
    required this.biggestImpactName,
    required this.biggestImpactDescription,
  });
}
