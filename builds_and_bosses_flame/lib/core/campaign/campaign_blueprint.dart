enum CampaignLevelMode { levelDown, levelUp }

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

  CampaignBlueprint({
    required this.bossId,
    required this.bossLevel,
    required this.heroLevel,
    required this.levelMode,
    required Map<String, int> classLevels,
    required Map<String, int> abilityScores,
  }) : classLevels = Map.unmodifiable(classLevels),
       abilityScores = Map.unmodifiable(abilityScores);

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
    if (heroLevel != progression.expectedHeroLevel(levelMode)) {
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

  int expectedHeroLevel(CampaignLevelMode mode) {
    switch (mode) {
      case CampaignLevelMode.levelDown:
        return 1;
      case CampaignLevelMode.levelUp:
        return 2;
    }
  }

  CampaignBlueprint firstBossBlueprint({
    required CampaignLevelMode levelMode,
    required Map<String, int> classLevels,
    required Map<String, int> abilityScores,
  }) {
    return CampaignBlueprint(
      bossId: firstBossId,
      bossLevel: firstBossLevel,
      heroLevel: expectedHeroLevel(levelMode),
      levelMode: levelMode,
      classLevels: classLevels,
      abilityScores: abilityScores,
    );
  }
}
