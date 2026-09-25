import 'package:flutter_test/flutter_test.dart';
import 'package:builds_and_bosses_flame/core/dnd/character_catalog.dart';
import 'package:builds_and_bosses_flame/core/dnd/character_stats.dart';

void main() {
  test('uses the 2024 ruleset and has the four requested species', () {
    expect(CharacterCatalog.ruleset, CharacterRuleset.dnd2024);
    expect(
      CharacterCatalog.races.map((race) => race.id),
      containsAll(<String>['human', 'elf', 'dwarf', 'halfling']),
    );
  });

  test('2024 species do not modify ability scores', () {
    final baseStats = CharacterStats(
      name: 'Test Hero',
      maxHp: 20,
      armorClass: 10,
      strength: 10,
      dexterity: 10,
      constitution: 10,
      intelligence: 10,
      wisdom: 10,
      charisma: 10,
    );

    for (final race in CharacterCatalog.races) {
      expect(race.abilityBonuses, isEmpty, reason: race.id);
    }

    expect(baseStats.strength, 10);
    expect(baseStats.dexterity, 10);
    expect(baseStats.constitution, 10);
  });

  test('2024 species traits are sourced by species', () {
    expect(
      CharacterCatalog.racialAbilities('elf').map((ability) => ability.id),
      containsAll(<String>[
        'darkvision_60',
        'elven_lineage',
        'fey_ancestry',
        'keen_senses',
        'trance',
      ]),
    );
    expect(
      CharacterCatalog.racialAbilities('dwarf').map((ability) => ability.id),
      containsAll(<String>[
        'darkvision_120',
        'dwarven_resilience',
        'dwarven_toughness',
        'stonecunning',
      ]),
    );
  });

  test('class abilities are limited to their class source', () {
    expect(
      CharacterCatalog.classAbilities('fighter').map((ability) => ability.id),
      containsAll(<String>['fighting_style', 'second_wind', 'action_surge']),
    );
    expect(
      CharacterCatalog.classAbilities('rogue').map((ability) => ability.id),
      containsAll(<String>['expertise', 'sneak_attack', 'cunning_action']),
    );
  });
}
