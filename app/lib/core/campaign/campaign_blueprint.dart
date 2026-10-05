enum CampaignLevelMode { levelDown, levelUp, custom }

enum CampaignValidationError {
  emptyClassBuild,
  invalidClassLevel,
  tooManyClasses,
  totalLevelMismatch,
  invalidHeroLevel,
  invalidBossLevel,
  emptyAbilityScores,
}

class CampaignValidationResult {
  final List<CampaignValidationError> errors;

  const CampaignValidationResult(this.errors);

  bool get isValid => errors.isEmpty;
}

class CampaignBlueprint {
  final String bossId;
  final int bossLevel;
  final int heroLevel;
  final CampaignLevelMode levelMode;
  final Map<String, int> classLevels;
  final Map<String, int> abilityScores;
  final String raceId;
  final List<String> selectedAbilityIds;

  CampaignBlueprint({
    required this.bossId,
    required this.bossLevel,
    required this.heroLevel,
    required this.levelMode,
    required Map<String, int> classLevels,
    required Map<String, int> abilityScores,
    this.raceId = 'human',
    List<String> selectedAbilityIds = const [],
  }) : classLevels = Map.unmodifiable(classLevels),
       abilityScores = Map.unmodifiable(abilityScores),
       selectedAbilityIds = List.unmodifiable(selectedAbilityIds);

  int get totalClassLevels =>
      classLevels.values.fold(0, (sum, level) => sum + level);

  CampaignValidationResult validate(CampaignProgression progression) {
    final errors = <CampaignValidationError>[];

    if (classLevels.isEmpty) {
      errors.add(CampaignValidationError.emptyClassBuild);
    }
    if (classLevels.length > CampaignProgression.maxClassCount) {
      errors.add(CampaignValidationError.tooManyClasses);
    }
    if (classLevels.values.any(
      (level) => level < CampaignProgression.minimumClassLevel,
    )) {
      errors.add(CampaignValidationError.invalidClassLevel);
    }
    if (levelMode == CampaignLevelMode.custom) {
      if (heroLevel < 1 || heroLevel > 20) {
        errors.add(CampaignValidationError.invalidHeroLevel);
      }
    } else if (heroLevel != progression.expectedHeroLevel(levelMode)) {
      errors.add(CampaignValidationError.invalidHeroLevel);
    }
    if (totalClassLevels != heroLevel) {
      errors.add(CampaignValidationError.totalLevelMismatch);
    }
    if (bossLevel != CampaignProgression.firstBossLevel) {
      errors.add(CampaignValidationError.invalidBossLevel);
    }
    if (abilityScores.isEmpty) {
      errors.add(CampaignValidationError.emptyAbilityScores);
    }

    return CampaignValidationResult(errors);
  }
}

class CampaignProgression {
  static const String firstBossId = 'boss_001';
  static const int firstBossLevel = 4;
  static const int maxClassCount = 3;
  static const int minimumClassLevel = 1;

  const CampaignProgression();

  int expectedHeroLevel(CampaignLevelMode mode, {int? customLevel}) {
    switch (mode) {
      case CampaignLevelMode.levelDown:
        return 1;
      case CampaignLevelMode.levelUp:
        return 2;
      case CampaignLevelMode.custom:
        return (customLevel ?? 1).clamp(1, 20);
    }
  }

  CampaignBlueprint firstBossBlueprint({
    required CampaignLevelMode levelMode,
    required Map<String, int> classLevels,
    required Map<String, int> abilityScores,
    String raceId = 'human',
    List<String> selectedAbilityIds = const [],
    int? customLevel,
  }) {
    return CampaignBlueprint(
      bossId: firstBossId,
      bossLevel: firstBossLevel,
      heroLevel: expectedHeroLevel(levelMode, customLevel: customLevel),
      levelMode: levelMode,
      classLevels: classLevels,
      abilityScores: abilityScores,
      raceId: raceId,
      selectedAbilityIds: selectedAbilityIds,
    );
  }
}
