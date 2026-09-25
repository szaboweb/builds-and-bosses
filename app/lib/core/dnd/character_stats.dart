import 'dart:math';

import '../config/game_rules_config.dart';
import 'character_catalog.dart';

/// D&D character stats model with config-driven dynamic physics & combat scaling.
class CharacterStats {
  final String name;
  final String classId;
  final String weaponId;
  final String raceId;
  final int level;
  final int maxHp;
  int currentHp;
  final int armorClass;
  final CharacterAlignment alignment;

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
    this.classId = 'fighter',
    this.weaponId = 'longsword',
    this.raceId = 'human',
    this.level = 1,
    required this.maxHp,
    int? currentHp,
    required this.armorClass,
    this.alignment = CharacterAlignment.neutral,
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

  WeaponRangeConfig get weaponRange => config.combat.weaponRangeFor(weaponId);
  double get meleeRange => weaponRange.meleeReach;
  double? get thrownNormalRange => weaponRange.thrownNormalRange;
  double? get thrownLongRange => weaponRange.thrownLongRange;

  int get spellcastingAbilityMod {
    switch (classId) {
      case 'wizard':
        return intelligenceMod;
      case 'cleric':
        return wisdomMod;
      default:
        return charismaMod;
    }
  }

  int get spellAttackBonus => spellcastingAbilityMod + proficiencyBonus;

  // --- Dynamic Stat-Driven Physical Attributes ---

  /// Dynamic vertical jump velocity derived from Strength (negative is upward).
  double get jumpVelocity => config.physics.calculateJumpVelocity(strengthMod);

  /// Peak jump height in pixels based on current Strength modifier and gravity.
  double get maxJumpHeight => config.physics.calculateJumpHeight(strengthMod);

  /// Dynamic horizontal movement speed in px/s derived from Dexterity.
  double get moveSpeed => config.physics.calculateMoveSpeed(dexterityMod);
  double get darkvisionRadius => config.vision.darkvisionRadiusFor(raceId);

  bool canWearEquipmentSet(AlignmentEquipmentSet equipmentSet) {
    return equipmentSet.isAllowedFor(alignment);
  }

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
      weaponId: 'longsword',
      raceId: 'human',
      classId: 'fighter',
      level: 3,
      maxHp: computedHp,
      armorClass: 16, // Chain Mail + Shield
      alignment: CharacterAlignment.lawfulGood,
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
      alignment: CharacterAlignment.neutral,
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
    String? classId,
    String? weaponId,
    String? raceId,
    int? level,
    int? maxHp,
    int? currentHp,
    int? armorClass,
    CharacterAlignment? alignment,
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
      classId: classId ?? this.classId,
      weaponId: weaponId ?? this.weaponId,
      raceId: raceId ?? this.raceId,
      level: level ?? this.level,
      maxHp: maxHp ?? this.maxHp,
      currentHp: currentHp ?? this.currentHp,
      armorClass: armorClass ?? this.armorClass,
      alignment: alignment ?? this.alignment,
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
    'classId': classId,
    'weaponId': weaponId,
    'raceId': raceId,
    'level': level,
    'maxHp': maxHp,
    'currentHp': currentHp,
    'armorClass': armorClass,
    'alignment': alignment.code,
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
      classId: json['classId'] as String? ?? 'fighter',
      weaponId: json['weaponId'] as String? ?? 'longsword',
      raceId: json['raceId'] as String? ?? 'human',
      level: json['level'] as int? ?? 1,
      maxHp: json['maxHp'] as int? ?? 20,
      currentHp: json['currentHp'] as int?,
      armorClass: json['armorClass'] as int? ?? 10,
      alignment:
          CharacterAlignment.fromCode(json['alignment'] as String?) ??
          CharacterAlignment.fromLabel(json['alignment'] as String?) ??
          CharacterAlignment.neutral,
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
