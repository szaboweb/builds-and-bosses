import 'package:flutter_test/flutter_test.dart';
import 'package:builds_and_bosses_flame/core/campaign/campaign_blueprint.dart';

void main() {
  const progression = CampaignProgression();
  const abilityScores = {
    'STR': 16,
    'DEX': 12,
    'CON': 14,
    'INT': 10,
    'WIS': 12,
    'CHA': 10,
  };

  test('creates a valid level-down blueprint for the first boss', () {
    final blueprint = progression.firstBossBlueprint(
      levelMode: CampaignLevelMode.levelDown,
      classLevels: const {'Fighter': 1},
      abilityScores: abilityScores,
    );

    final result = blueprint.validate(progression);

    expect(blueprint.bossId, equals(CampaignProgression.firstBossId));
    expect(blueprint.bossLevel, equals(4));
    expect(blueprint.heroLevel, equals(1));
    expect(result.isValid, isTrue);
  });

  test('creates a valid level-up blueprint with multiclass levels', () {
    final blueprint = progression.firstBossBlueprint(
      levelMode: CampaignLevelMode.levelUp,
      classLevels: const {'Fighter': 1, 'Rogue': 1},
      abilityScores: abilityScores,
    );

    expect(blueprint.validate(progression).isValid, isTrue);
    expect(blueprint.totalClassLevels, equals(2));
  });

  test('rejects a build with the wrong total level', () {
    final blueprint = CampaignBlueprint(
      bossId: CampaignProgression.firstBossId,
      bossLevel: CampaignProgression.firstBossLevel,
      heroLevel: 2,
      levelMode: CampaignLevelMode.levelUp,
      classLevels: const {'Fighter': 1},
      abilityScores: abilityScores,
    );

    final result = blueprint.validate(progression);

    expect(result.isValid, isFalse);
    expect(result.errors, contains(CampaignValidationError.totalLevelMismatch));
  });

  test('rejects more than three classes and an empty ability set', () {
    final blueprint = progression.firstBossBlueprint(
      levelMode: CampaignLevelMode.levelUp,
      classLevels: const {'Fighter': 1, 'Rogue': 1, 'Wizard': 1, 'Cleric': 1},
      abilityScores: const {},
    );

    final result = blueprint.validate(progression);

    expect(result.errors, contains(CampaignValidationError.tooManyClasses));
    expect(result.errors, contains(CampaignValidationError.emptyAbilityScores));
  });
}
