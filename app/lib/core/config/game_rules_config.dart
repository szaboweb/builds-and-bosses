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
    return (baseMoveSpeed + (dexterityMod * dexMoveSpeedScaling)).clamp(
      60.0,
      400.0,
    );
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
      baseJumpVelocity:
          (json['baseJumpVelocity'] as num?)?.toDouble() ?? -410.0,
      strJumpVelocityScaling:
          (json['strJumpVelocityScaling'] as num?)?.toDouble() ?? -22.0,
      baseMoveSpeed: (json['baseMoveSpeed'] as num?)?.toDouble() ?? 180.0,
      dexMoveSpeedScaling:
          (json['dexMoveSpeedScaling'] as num?)?.toDouble() ?? 12.0,
      baseDashSpeed: (json['baseDashSpeed'] as num?)?.toDouble() ?? 520.0,
      dashDuration: (json['dashDuration'] as num?)?.toDouble() ?? 0.22,
    );
  }
}

class WeaponRangeConfig {
  final String id;
  final double meleeReach;
  final double? thrownNormalRange;
  final double? thrownLongRange;

  const WeaponRangeConfig({
    required this.id,
    required this.meleeReach,
    this.thrownNormalRange,
    this.thrownLongRange,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'meleeReach': meleeReach,
    'thrownNormalRange': thrownNormalRange,
    'thrownLongRange': thrownLongRange,
  };

  factory WeaponRangeConfig.fromJson(Map<String, dynamic> json) {
    return WeaponRangeConfig(
      id: json['id'] as String,
      meleeReach: (json['meleeReach'] as num).toDouble(),
      thrownNormalRange: (json['thrownNormalRange'] as num?)?.toDouble(),
      thrownLongRange: (json['thrownLongRange'] as num?)?.toDouble(),
    );
  }
}

class VisionConfig {
  final double humanDarkvisionRadius;
  final double elfDarkvisionRadius;
  final double dwarfDarkvisionRadius;
  final double darknessIntensity;

  const VisionConfig({
    this.humanDarkvisionRadius = 0,
    this.elfDarkvisionRadius = 480,
    this.dwarfDarkvisionRadius = 960,
    this.darknessIntensity = 0.9,
  });

  double darkvisionRadiusFor(String raceId) {
    switch (raceId) {
      case 'elf':
        return elfDarkvisionRadius;
      case 'dwarf':
        return dwarfDarkvisionRadius;
      default:
        return humanDarkvisionRadius;
    }
  }

  Map<String, dynamic> toJson() => {
    'humanDarkvisionRadius': humanDarkvisionRadius,
    'elfDarkvisionRadius': elfDarkvisionRadius,
    'dwarfDarkvisionRadius': dwarfDarkvisionRadius,
    'darknessIntensity': darknessIntensity,
  };

  factory VisionConfig.fromJson(Map<String, dynamic> json) => VisionConfig(
    humanDarkvisionRadius:
        (json['humanDarkvisionRadius'] as num?)?.toDouble() ?? 0,
    elfDarkvisionRadius:
        (json['elfDarkvisionRadius'] as num?)?.toDouble() ?? 480,
    dwarfDarkvisionRadius:
        (json['dwarfDarkvisionRadius'] as num?)?.toDouble() ?? 960,
    darknessIntensity:
        (json['darknessIntensity'] as num?)?.toDouble() ?? 0.9,
  );
}

class InventoryConfig {
  final int maxInventorySlots;
  final int maxArmorySlots;
  final int maxItemsPerEquipmentSet;

  const InventoryConfig({
    this.maxInventorySlots = 20,
    this.maxArmorySlots = 3,
    this.maxItemsPerEquipmentSet = 6,
  });

  Map<String, dynamic> toJson() => {
    'maxInventorySlots': maxInventorySlots,
    'maxArmorySlots': maxArmorySlots,
    'maxItemsPerEquipmentSet': maxItemsPerEquipmentSet,
  };

  factory InventoryConfig.fromJson(Map<String, dynamic> json) => InventoryConfig(
    maxInventorySlots: json['maxInventorySlots'] as int? ?? 20,
    maxArmorySlots: json['maxArmorySlots'] as int? ?? 3,
    maxItemsPerEquipmentSet: json['maxItemsPerEquipmentSet'] as int? ?? 6,
  );
}

class CombatConfig {
  /// Maximum distance for a melee attack in world pixels.
  final double meleeRange;
  final double meleeVerticalTolerance;
  final double rangedNormalRange;
  final double rangedLongRange;
  final double spellRange;
  final Map<String, WeaponRangeConfig> weaponRanges;

  /// Base HP for a level 1 Fighter without CON mod.
  final int baseFighterHp;

  /// HP gained per level for a Fighter (d10 hit die average = 6).
  final int fighterHpPerLevel;

  /// Base unarmored Armor Class.
  final int baseUnarmoredAc;

  const CombatConfig({
    this.meleeRange = 110.0,
    this.meleeVerticalTolerance = 1.5,
    this.rangedNormalRange = 420.0,
    this.rangedLongRange = 900.0,
    this.spellRange = 600.0,
    this.weaponRanges = const {
      'dagger': WeaponRangeConfig(
        id: 'dagger',
        meleeReach: 110.0,
        thrownNormalRange: 400.0,
        thrownLongRange: 1200.0,
      ),
      'shortsword': WeaponRangeConfig(id: 'shortsword', meleeReach: 110.0),
      'longsword': WeaponRangeConfig(id: 'longsword', meleeReach: 110.0),
      'greatsword': WeaponRangeConfig(id: 'greatsword', meleeReach: 110.0),
    },
    this.baseFighterHp = 10,
    this.fighterHpPerLevel = 6,
    this.baseUnarmoredAc = 10,
  });

  WeaponRangeConfig weaponRangeFor(String weaponId) =>
      weaponRanges[weaponId] ?? weaponRanges['longsword']!;

  /// Computes max HP for a character at a given level with Constitution modifier.
  int calculateMaxHp(int level, int conMod, {int? baseHpOverride}) {
    final base = baseHpOverride ?? baseFighterHp;
    final levelBonuses = (level - 1) * (fighterHpPerLevel + conMod);
    return (base + conMod + levelBonuses).clamp(1, 9999);
  }

  Map<String, dynamic> toJson() => {
    'meleeRange': meleeRange,
    'meleeVerticalTolerance': meleeVerticalTolerance,
    'rangedNormalRange': rangedNormalRange,
    'rangedLongRange': rangedLongRange,
    'spellRange': spellRange,
    'weaponRanges': weaponRanges.map(
      (id, range) => MapEntry(id, range.toJson()),
    ),
    'baseFighterHp': baseFighterHp,
    'fighterHpPerLevel': fighterHpPerLevel,
    'baseUnarmoredAc': baseUnarmoredAc,
  };

  factory CombatConfig.fromJson(Map<String, dynamic> json) {
    final jsonWeaponRanges = json['weaponRanges'] as Map<String, dynamic>?;
    final weaponRanges = jsonWeaponRanges?.map(
          (id, value) => MapEntry(
            id,
            WeaponRangeConfig.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          ),
        ) ??
        const CombatConfig().weaponRanges;
    return CombatConfig(
      meleeRange: (json['meleeRange'] as num?)?.toDouble() ?? 110.0,
        meleeVerticalTolerance:
          (json['meleeVerticalTolerance'] as num?)?.toDouble() ?? 1.5,
      rangedNormalRange:
          (json['rangedNormalRange'] as num?)?.toDouble() ?? 420.0,
      rangedLongRange:
          (json['rangedLongRange'] as num?)?.toDouble() ?? 900.0,
      spellRange: (json['spellRange'] as num?)?.toDouble() ?? 600.0,
      weaponRanges: weaponRanges,
      baseFighterHp: json['baseFighterHp'] as int? ?? 10,
      fighterHpPerLevel: json['fighterHpPerLevel'] as int? ?? 6,
      baseUnarmoredAc: json['baseUnarmoredAc'] as int? ?? 10,
    );
  }
}

class CooldownConfig {
  final double actionCooldown;
  final double bonusActionCooldown;
  final double reactionCooldown;
  final double slashCooldown;
  final double dashCooldown;
  final double secondWindCooldown;

  const CooldownConfig({
    this.actionCooldown = 0.8,
    this.bonusActionCooldown = 0.4,
    this.reactionCooldown = 1.0,
    this.slashCooldown = 0.8,
    this.dashCooldown = 2.5,
    this.secondWindCooldown = 8.0,
  });

  Map<String, dynamic> toJson() => {
    'actionCooldown': actionCooldown,
    'bonusActionCooldown': bonusActionCooldown,
    'reactionCooldown': reactionCooldown,
    'slashCooldown': slashCooldown,
    'dashCooldown': dashCooldown,
    'secondWindCooldown': secondWindCooldown,
  };

  factory CooldownConfig.fromJson(Map<String, dynamic> json) {
    return CooldownConfig(
      actionCooldown: (json['actionCooldown'] as num?)?.toDouble() ?? 0.8,
      bonusActionCooldown:
          (json['bonusActionCooldown'] as num?)?.toDouble() ?? 0.4,
      reactionCooldown: (json['reactionCooldown'] as num?)?.toDouble() ?? 1.0,
      slashCooldown: (json['slashCooldown'] as num?)?.toDouble() ?? 0.8,
      dashCooldown: (json['dashCooldown'] as num?)?.toDouble() ?? 2.5,
      secondWindCooldown:
          (json['secondWindCooldown'] as num?)?.toDouble() ?? 8.0,
    );
  }
}

class PointBuyConfig {
  /// Total point budget from the 2024 Free Rules character creation rules.
  final int totalBudget;

  /// Minimum starting attribute score.
  final int minScore;

  /// Maximum starting base attribute score before racial/level bonuses.
  final int maxScore;

  /// Point buy cost table: maps attribute score to cumulative points spent.
  final Map<int, int> scoreCostTable;

  const PointBuyConfig({
    this.totalBudget = 27,
    this.minScore = 8,
    this.maxScore = 18,
    this.scoreCostTable = const {
      8: 0,
      9: 1,
      10: 2,
      11: 3,
      12: 4,
      13: 5,
      14: 7,
      15: 9,
      16: 12,
      17: 15,
      18: 19,
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
  final CooldownConfig cooldowns;
  final VisionConfig vision;
  final InventoryConfig inventory;
  final PointBuyConfig pointBuy;

  const GameRulesConfig({
    this.physics = const PhysicsConfig(),
    this.combat = const CombatConfig(),
    this.cooldowns = const CooldownConfig(),
    this.vision = const VisionConfig(),
    this.inventory = const InventoryConfig(),
    this.pointBuy = const PointBuyConfig(),
  });

  Map<String, dynamic> toJson() => {
    'physics': physics.toJson(),
    'combat': combat.toJson(),
    'cooldowns': cooldowns.toJson(),
    'vision': vision.toJson(),
    'inventory': inventory.toJson(),
  };

  factory GameRulesConfig.fromJson(Map<String, dynamic> json) {
    return GameRulesConfig(
      physics: json['physics'] != null
          ? PhysicsConfig.fromJson(json['physics'] as Map<String, dynamic>)
          : const PhysicsConfig(),
      combat: json['combat'] != null
          ? CombatConfig.fromJson(json['combat'] as Map<String, dynamic>)
          : const CombatConfig(),
      cooldowns: json['cooldowns'] != null
          ? CooldownConfig.fromJson(json['cooldowns'] as Map<String, dynamic>)
          : const CooldownConfig(),
          vision: json['vision'] != null
            ? VisionConfig.fromJson(json['vision'] as Map<String, dynamic>)
            : const VisionConfig(),
        inventory: json['inventory'] != null
            ? InventoryConfig.fromJson(
                json['inventory'] as Map<String, dynamic>,
              )
            : const InventoryConfig(),
    );
  }
}
