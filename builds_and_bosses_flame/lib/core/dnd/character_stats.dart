import 'dart:math';
import '../config/game_rules_config.dart';

/// D&D character stats model with config-driven dynamic physics & combat scaling.
class CharacterStats {
  final String name;
  final int level;
  final int maxHp;
  int currentHp;
  final int armorClass;

  // The 6 Core D&D Ability Scores
  final int strength;
  final int dexterity;
  final int constitution;
  final int intelligence;
  final int wisdom;
  final int charisma;

  /// Game rules configuration reference for dynamic scaling
  final GameRulesConfig config;

  CharacterStats({
    required this.name,
    this.level = 1,
    required this.maxHp,
    int? currentHp,
    required this.armorClass,
    this.strength = 10,
    this.dexterity = 10,
    this.constitution = 10,
    this.intelligence = 10,
    this.wisdom = 10,
    this.charisma = 10,
    this.config = const GameRulesConfig(),
  }) : currentHp = currentHp ?? maxHp;

  // Ability Modifiers: floor((Score - 10) / 2)
  int get strengthMod => ((strength - 10) / 2).floor();
  int get dexterityMod => ((dexterity - 10) / 2).floor();
  int get constitutionMod => ((constitution - 10) / 2).floor();
  int get intelligenceMod => ((intelligence - 10) / 2).floor();
  int get wisdomMod => ((wisdom - 10) / 2).floor();
  int get charismaMod => ((charisma - 10) / 2).floor();

  /// Proficiency bonus scales with level (D&D 5e standard).
  int get proficiencyBonus => 2 + ((level - 1) ~/ 4);

  /// Melee attack bonus = Strength mod + proficiency bonus.
  int get meleeAttackBonus => strengthMod + proficiencyBonus;

  // --- Dynamic Stat-Driven Physical Attributes ---

  /// Dynamic vertical jump velocity derived from Strength (negative is upward).
  double get jumpVelocity => config.physics.calculateJumpVelocity(strengthMod);

  /// Peak jump height in pixels based on current Strength modifier and gravity.
  double get maxJumpHeight => config.physics.calculateJumpHeight(strengthMod);

  /// Dynamic horizontal movement speed in px/s derived from Dexterity.
  double get moveSpeed => config.physics.calculateMoveSpeed(dexterityMod);

  bool get isDead => currentHp <= 0;

  void takeDamage(int amount) {
    currentHp = max(0, currentHp - amount);
  }

  void heal(int amount) {
    currentHp = min(maxHp, currentHp + amount);
  }

  /// Preset for the Level 3 Fighter protagonist.
  factory CharacterStats.fighterProtagonist({GameRulesConfig? config}) {
    final rules = config ?? GameRulesConfig.standard;
    const conMod = 2; // CON 14
    final computedHp = rules.combat.calculateMaxHp(3, conMod);

    return CharacterStats(
      name: 'Fighter',
      level: 3,
      maxHp: computedHp,
      armorClass: 16, // Chain Mail + Shield
      strength: 16, // +3 mod -> jumpVelocity = -476 px/s (~116 px height)
      dexterity: 12, // +1 mod -> moveSpeed = 192 px/s
      constitution: 14, // +2 mod
      intelligence: 10,
      wisdom: 12,
      charisma: 10,
      config: rules,
    );
  }

  /// Preset for the Training Dummy / Vanguard Boss.
  factory CharacterStats.trainingDummy({GameRulesConfig? config}) {
    return CharacterStats(
      name: 'Training Golem',
      level: 2,
      maxHp: 35,
      armorClass: 13,
      strength: 14,
      dexterity: 8,
      constitution: 14,
      intelligence: 6,
      wisdom: 10,
      charisma: 6,
      config: config ?? GameRulesConfig.standard,
    );
  }

  /// Creates a copy of this CharacterStats with updated values.
  CharacterStats copyWith({
    String? name,
    int? level,
    int? maxHp,
    int? currentHp,
    int? armorClass,
    int? strength,
    int? dexterity,
    int? constitution,
    int? intelligence,
    int? wisdom,
    int? charisma,
    GameRulesConfig? config,
  }) {
    return CharacterStats(
      name: name ?? this.name,
      level: level ?? this.level,
      maxHp: maxHp ?? this.maxHp,
      currentHp: currentHp ?? this.currentHp,
      armorClass: armorClass ?? this.armorClass,
      strength: strength ?? this.strength,
      dexterity: dexterity ?? this.dexterity,
      constitution: constitution ?? this.constitution,
      intelligence: intelligence ?? this.intelligence,
      wisdom: wisdom ?? this.wisdom,
      charisma: charisma ?? this.charisma,
      config: config ?? this.config,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'level': level,
        'maxHp': maxHp,
        'currentHp': currentHp,
        'armorClass': armorClass,
        'strength': strength,
        'dexterity': dexterity,
        'constitution': constitution,
        'intelligence': intelligence,
        'wisdom': wisdom,
        'charisma': charisma,
      };

  factory CharacterStats.fromJson(
    Map<String, dynamic> json, {
    GameRulesConfig? config,
  }) {
    return CharacterStats(
      name: json['name'] as String? ?? 'Hero',
      level: json['level'] as int? ?? 1,
      maxHp: json['maxHp'] as int? ?? 20,
      currentHp: json['currentHp'] as int?,
      armorClass: json['armorClass'] as int? ?? 10,
      strength: json['strength'] as int? ?? 10,
      dexterity: json['dexterity'] as int? ?? 10,
      constitution: json['constitution'] as int? ?? 10,
      intelligence: json['intelligence'] as int? ?? 10,
      wisdom: json['wisdom'] as int? ?? 10,
      charisma: json['charisma'] as int? ?? 10,
      config: config ?? GameRulesConfig.standard,
    );
  }
}
