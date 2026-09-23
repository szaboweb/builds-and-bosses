/// Centralized, config-driven game rules, physics constants, point buy tables,
/// and combat formulas for Builds & Bosses.
///
/// Eliminates hardcoded magic numbers across the codebase.
class PhysicsConfig {
  /// Gravity acceleration in px/s^2.
  final double baseGravity;

  /// Base vertical impulse for jump in px/s (negative is upward).
  final double baseJumpVelocity;

  /// Vertical impulse added per point of Strength modifier (negative is upward).
  final double strJumpVelocityScaling;

  /// Base horizontal run speed in px/s.
  final double baseMoveSpeed;

  /// Horizontal speed added per point of Dexterity modifier.
  final double dexMoveSpeedScaling;

  /// Horizontal speed during dash in px/s.
  final double baseDashSpeed;

  /// Dash duration in seconds.
  final double dashDuration;

  const PhysicsConfig({
    this.baseGravity = 980.0,
    this.baseJumpVelocity = -410.0,
    this.strJumpVelocityScaling = -22.0,
    this.baseMoveSpeed = 180.0,
    this.dexMoveSpeedScaling = 12.0,
    this.baseDashSpeed = 520.0,
    this.dashDuration = 0.22,
  });

  /// Computes the initial vertical jump velocity based on Strength modifier.
  double calculateJumpVelocity(int strengthMod) {
    return baseJumpVelocity + (strengthMod * strJumpVelocityScaling);
  }

  /// Computes theoretical peak jump height in pixels: h = v0^2 / (2 * g).
  double calculateJumpHeight(int strengthMod) {
    final v0 = calculateJumpVelocity(strengthMod).abs();
    return (v0 * v0) / (2 * baseGravity);
  }

  /// Computes horizontal movement speed based on Dexterity modifier.
  double calculateMoveSpeed(int dexterityMod) {
    return (baseMoveSpeed + (dexterityMod * dexMoveSpeedScaling)).clamp(60.0, 400.0);
  }

  Map<String, dynamic> toJson() => {
        'baseGravity': baseGravity,
        'baseJumpVelocity': baseJumpVelocity,
        'strJumpVelocityScaling': strJumpVelocityScaling,
        'baseMoveSpeed': baseMoveSpeed,
        'dexMoveSpeedScaling': dexMoveSpeedScaling,
        'baseDashSpeed': baseDashSpeed,
        'dashDuration': dashDuration,
      };

  factory PhysicsConfig.fromJson(Map<String, dynamic> json) {
    return PhysicsConfig(
      baseGravity: (json['baseGravity'] as num?)?.toDouble() ?? 980.0,
      baseJumpVelocity: (json['baseJumpVelocity'] as num?)?.toDouble() ?? -410.0,
      strJumpVelocityScaling: (json['strJumpVelocityScaling'] as num?)?.toDouble() ?? -22.0,
      baseMoveSpeed: (json['baseMoveSpeed'] as num?)?.toDouble() ?? 180.0,
      dexMoveSpeedScaling: (json['dexMoveSpeedScaling'] as num?)?.toDouble() ?? 12.0,
      baseDashSpeed: (json['baseDashSpeed'] as num?)?.toDouble() ?? 520.0,
      dashDuration: (json['dashDuration'] as num?)?.toDouble() ?? 0.22,
    );
  }
}

class CombatConfig {
  /// Base HP for a level 1 Fighter without CON mod.
  final int baseFighterHp;

  /// HP gained per level for a Fighter (d10 hit die average = 6).
  final int fighterHpPerLevel;

  /// Base unarmored Armor Class.
  final int baseUnarmoredAc;

  const CombatConfig({
    this.baseFighterHp = 10,
    this.fighterHpPerLevel = 6,
    this.baseUnarmoredAc = 10,
  });

  /// Computes max HP for a character at a given level with Constitution modifier.
  int calculateMaxHp(int level, int conMod, {int? baseHpOverride}) {
    final base = baseHpOverride ?? baseFighterHp;
    final levelBonuses = (level - 1) * (fighterHpPerLevel + conMod);
    return (base + conMod + levelBonuses).clamp(1, 9999);
  }

  Map<String, dynamic> toJson() => {
        'baseFighterHp': baseFighterHp,
        'fighterHpPerLevel': fighterHpPerLevel,
        'baseUnarmoredAc': baseUnarmoredAc,
      };

  factory CombatConfig.fromJson(Map<String, dynamic> json) {
    return CombatConfig(
      baseFighterHp: json['baseFighterHp'] as int? ?? 10,
      fighterHpPerLevel: json['fighterHpPerLevel'] as int? ?? 6,
      baseUnarmoredAc: json['baseUnarmoredAc'] as int? ?? 10,
    );
  }
}

class PointBuyConfig {
  /// Total point budget for character creation (DDO 28-point standard).
  final int totalBudget;

  /// Minimum starting attribute score.
  final int minScore;

  /// Maximum starting base attribute score before racial/level bonuses.
  final int maxScore;

  /// Point buy cost table: maps attribute score to cumulative points spent.
  final Map<int, int> scoreCostTable;

  const PointBuyConfig({
    this.totalBudget = 28,
    this.minScore = 8,
    this.maxScore = 18,
    this.scoreCostTable = const {
      8: 0,
      9: 1,
      10: 2,
      11: 3,
      12: 4,
      13: 5,
      14: 6,
      15: 8,
      16: 10,
      17: 13,
      18: 16,
    },
  });

  /// Cumulative points required to purchase [score].
  int costForScore(int score) {
    final clamped = score.clamp(minScore, maxScore);
    return scoreCostTable[clamped] ?? 0;
  }

  /// Calculates total points spent across a map of attribute scores.
  int calculateTotalSpent(Map<String, int> scores) {
    int total = 0;
    for (final score in scores.values) {
      total += costForScore(score);
    }
    return total;
  }

  /// Returns remaining points from budget given the scores map.
  int remainingPoints(Map<String, int> scores) {
    return totalBudget - calculateTotalSpent(scores);
  }

  /// Checks if increasing an attribute score is permissible under the budget.
  bool canIncrease(Map<String, int> scores, String attributeKey) {
    final currentScore = scores[attributeKey] ?? minScore;
    if (currentScore >= maxScore) return false;
    final currentCost = costForScore(currentScore);
    final nextCost = costForScore(currentScore + 1);
    final costDelta = nextCost - currentCost;
    return remainingPoints(scores) >= costDelta;
  }

  /// Checks if decreasing an attribute score is permissible.
  bool canDecrease(Map<String, int> scores, String attributeKey) {
    final currentScore = scores[attributeKey] ?? minScore;
    return currentScore > minScore;
  }
}

/// Global Game Rules configuration root.
class GameRulesConfig {
  static GameRulesConfig standard = const GameRulesConfig();

  final PhysicsConfig physics;
  final CombatConfig combat;
  final PointBuyConfig pointBuy;

  const GameRulesConfig({
    this.physics = const PhysicsConfig(),
    this.combat = const CombatConfig(),
    this.pointBuy = const PointBuyConfig(),
  });

  Map<String, dynamic> toJson() => {
        'physics': physics.toJson(),
        'combat': combat.toJson(),
      };

  factory GameRulesConfig.fromJson(Map<String, dynamic> json) {
    return GameRulesConfig(
      physics: json['physics'] != null
          ? PhysicsConfig.fromJson(json['physics'] as Map<String, dynamic>)
          : const PhysicsConfig(),
      combat: json['combat'] != null
          ? CombatConfig.fromJson(json['combat'] as Map<String, dynamic>)
          : const CombatConfig(),
    );
  }
}
