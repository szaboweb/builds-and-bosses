enum CharacterRuleset { dnd2024 }

enum CharacterAlignment {
  lawfulGood(
    'LG',
    'Lawful Good',
    'Lawful Good creatures endeavor to do the right thing as expected by society.',
  ),
  neutralGood(
    'NG',
    'Neutral Good',
    'Neutral Good creatures do the best they can, working within rules but not feeling bound by them.',
  ),
  chaoticGood(
    'CG',
    'Chaotic Good',
    'Chaotic Good creatures act as their conscience directs with little regard for what others expect.',
  ),
  lawfulNeutral(
    'LN',
    'Lawful Neutral',
    'Lawful Neutral individuals act in accordance with law, tradition, or personal codes.',
  ),
  neutral(
    'N',
    'Neutral',
    'Neutral is the alignment of those who prefer to avoid moral questions and do not take sides.',
  ),
  chaoticNeutral(
    'CN',
    'Chaotic Neutral',
    'Chaotic Neutral creatures follow their whims, valuing personal freedom above all else.',
  ),
  lawfulEvil(
    'LE',
    'Lawful Evil',
    'Lawful Evil creatures methodically take what they want within the limits of a code of tradition, loyalty, or order.',
  ),
  neutralEvil(
    'NE',
    'Neutral Evil',
    'Neutral Evil is the alignment of those who are untroubled by the harm they cause as they pursue their desires.',
  ),
  chaoticEvil(
    'CE',
    'Chaotic Evil',
    'Chaotic Evil creatures act with arbitrary violence, spurred by their hatred or bloodlust.',
  );

  final String code;
  final String label;
  final String description;

  const CharacterAlignment(this.code, this.label, this.description);

  static CharacterAlignment? fromCode(String? value) {
    if (value == null) return null;
    for (final alignment in CharacterAlignment.values) {
      if (alignment.code == value || alignment.name == value) {
        return alignment;
      }
    }
    return null;
  }

  static CharacterAlignment? fromLabel(String? value) {
    if (value == null) return null;
    for (final alignment in CharacterAlignment.values) {
      if (alignment.label.toLowerCase() == value.toLowerCase()) {
        return alignment;
      }
    }
    return null;
  }
}

class AlignmentEquipmentSet {
  final String id;
  final String name;
  final String description;
  final List<CharacterAlignment> allowedAlignments;
  final List<String> itemIds;

  const AlignmentEquipmentSet({
    required this.id,
    required this.name,
    required this.description,
    required this.allowedAlignments,
    required this.itemIds,
  });

  bool isAllowedFor(CharacterAlignment alignment) =>
      allowedAlignments.contains(alignment);

  bool isAllowedForCode(String? value) {
    final alignment =
        CharacterAlignment.fromCode(value) ??
        CharacterAlignment.fromLabel(value);
    if (alignment == null) return false;
    return isAllowedFor(alignment);
  }
}

class CharacterAbilityDefinition {
  final String id;
  final String name;
  final String description;
  final String sourceId;
  final bool isRacial;

  const CharacterAbilityDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.sourceId,
    required this.isRacial,
  });
}

class CharacterRaceDefinition {
  final String id;
  final String name;
  final String description;
  final Map<String, int> abilityBonuses;
  final List<String> abilityIds;

  const CharacterRaceDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.abilityBonuses,
    required this.abilityIds,
  });
}

class CharacterClassDefinition {
  final String id;
  final String name;
  final String role;
  final String description;
  final List<String> abilityIds;

  const CharacterClassDefinition({
    required this.id,
    required this.name,
    required this.role,
    required this.description,
    required this.abilityIds,
  });
}

/// Static, read-only character creation database.
class CharacterCatalog {
  static const ruleset = CharacterRuleset.dnd2024;
  static const rulesSourceUrl =
      'https://www.dndbeyond.com/sources/dnd/br-2024/character-origins';
  static const characterCreationSourceUrl =
      'https://www.dndbeyond.com/sources/dnd/br-2024/creating-a-character#CreateYourCharacter';
  static const classRulesSourceUrl =
      'https://www.dndbeyond.com/sources/dnd/br-2024/character-classes';
  static const multiclassRulesSourceUrl =
      'https://www.dndbeyond.com/sources/dnd/br-2024/creating-a-character#Multiclassing';

  static const alignmentDefinitions = CharacterAlignment.values;

  static const equipmentSets = <AlignmentEquipmentSet>[
    AlignmentEquipmentSet(
      id: 'lawful_order_set',
      name: 'Lawful Order Set',
      description:
          'A disciplined set for those who uphold law, order, and tradition.',
      allowedAlignments: [
        CharacterAlignment.lawfulGood,
        CharacterAlignment.lawfulNeutral,
        CharacterAlignment.lawfulEvil,
      ],
      itemIds: ['steel-breastplate', 'crest-shield', 'vigil-sigil'],
    ),
    AlignmentEquipmentSet(
      id: 'balanced_guardian_set',
      name: 'Balanced Guardian Set',
      description: 'Neutral pieces meant for those who weigh mercy and practicality equally.',
      allowedAlignments: [
        CharacterAlignment.neutralGood,
        CharacterAlignment.neutral,
        CharacterAlignment.neutralEvil,
      ],
      itemIds: ['traveling-cloak', 'steady-helm', 'worn-buckler'],
    ),
    AlignmentEquipmentSet(
      id: 'chaotic_rebel_set',
      name: 'Chaotic Rebel Set',
      description:
          'A free-willed set for agents of personal freedom and ambition.',
      allowedAlignments: [
        CharacterAlignment.chaoticGood,
        CharacterAlignment.chaoticNeutral,
        CharacterAlignment.chaoticEvil,
      ],
      itemIds: ['wild-hood', 'scarred-leather', 'vanguard-daggers'],
    ),
  ];

  static List<AlignmentEquipmentSet> equipmentSetsForAlignment(
    CharacterAlignment alignment,
  ) {
    return equipmentSets
        .where((set) => set.allowedAlignments.contains(alignment))
        .toList();
  }

  static const races = <CharacterRaceDefinition>[
    CharacterRaceDefinition(
      id: 'human',
      name: 'Ember',
      description: 'Változatos, alkalmazkodó humanoid faj.',
      abilityBonuses: {},
      abilityIds: ['resourceful', 'skillful', 'versatile'],
    ),
    CharacterRaceDefinition(
      id: 'elf',
      name: 'Elf',
      description: 'Éles érzékű, ősi mágiával hangolt humanoid faj.',
      abilityBonuses: {},
      abilityIds: [
        'darkvision_60',
        'elven_lineage',
        'fey_ancestry',
        'keen_senses',
        'trance',
      ],
    ),
    CharacterRaceDefinition(
      id: 'dwarf',
      name: 'Törpe',
      description: 'Szívós humanoid faj, amely ellenálló a méreggel szemben.',
      abilityBonuses: {},
      abilityIds: [
        'darkvision_120',
        'dwarven_resilience',
        'dwarven_toughness',
        'stonecunning',
      ],
    ),
    CharacterRaceDefinition(
      id: 'halfling',
      name: 'Félszerzet',
      description: 'Kis termetű, fürge és meglepően bátor humanoid faj.',
      abilityBonuses: {},
      abilityIds: [
        'brave',
        'halfling_nimbleness',
        'halfling_luck',
        'naturally_stealthy',
      ],
    ),
  ];

  static const classes = <CharacterClassDefinition>[
    CharacterClassDefinition(
      id: 'fighter',
      name: 'Fighter',
      role: 'Frontvonal',
      description:
          'Erős közelharcos, aki páncéllal és fegyverrel tartja a frontot.',
      abilityIds: [
        'fighting_style',
        'second_wind',
        'weapon_mastery',
        'action_surge',
        'tactical_mind',
      ],
    ),
    CharacterClassDefinition(
      id: 'rogue',
      name: 'Rogue',
      role: 'Mobilis támadó',
      description: 'Gyors, pontos és magaslatokról különösen veszélyes.',
      abilityIds: [
        'expertise',
        'sneak_attack',
        'thieves_cant',
        'rogue_weapon_mastery',
        'cunning_action',
      ],
    ),
    CharacterClassDefinition(
      id: 'wizard',
      name: 'Wizard',
      role: 'Kontroll és mágia',
      description: 'Intelligenciára építő varázshasználó, aki a pályát is fegyverként használja.',
      abilityIds: [
        'wizard_spellcasting',
        'ritual_adept',
        'arcane_recovery',
        'scholar',
      ],
    ),
    CharacterClassDefinition(
      id: 'cleric',
      name: 'Cleric',
      role: 'Támogató',
      description: 'Isteni erővel gyógyít, véd és megtöri az átkokat.',
      abilityIds: ['cleric_spellcasting', 'divine_order', 'channel_divinity'],
    ),
  ];

  static const abilities = <CharacterAbilityDefinition>[
    CharacterAbilityDefinition(
      id: 'resourceful',
      name: 'Resourceful',
      description: 'Hosszú pihenő után Heroic Inspirationt kapsz.',
      sourceId: 'human',
      isRacial: true,
    ),
    CharacterAbilityDefinition(
      id: 'darkvision_60',
      name: 'Darkvision',
      description: '60 láb távolságig lát sötétben.',
      sourceId: 'elf',
      isRacial: true,
    ),
    CharacterAbilityDefinition(
      id: 'fey_ancestry',
      name: 'Fey Ancestry',
      description: 'Előnyt kapsz a Charmed állapot elkerülésére vagy megszüntetésére tett mentődobásokra.',
      sourceId: 'elf',
      isRacial: true,
    ),
    CharacterAbilityDefinition(
      id: 'elven_lineage',
      name: 'Elven Lineage',
      description: 'Drow, High Elf vagy Wood Elf lineage választása.',
      sourceId: 'elf',
      isRacial: true,
    ),
    CharacterAbilityDefinition(
      id: 'keen_senses',
      name: 'Keen Senses',
      description:
          'Jártasság Insight, Perception vagy Survival képzettség egyikében.',
      sourceId: 'elf',
      isRacial: true,
    ),
    CharacterAbilityDefinition(
      id: 'trance',
      name: 'Trance',
      description: 'Nem kell aludnod; 4 óra transz hosszú pihenésnek számít.',
      sourceId: 'elf',
      isRacial: true,
    ),
    CharacterAbilityDefinition(
      id: 'skillful',
      name: 'Skillful',
      description: 'Egy általad választott skillben jártasságot kapsz.',
      sourceId: 'human',
      isRacial: true,
    ),
    CharacterAbilityDefinition(
      id: 'versatile',
      name: 'Versatile',
      description: 'Egy Origin featet kapsz; a Skilled ajánlott.',
      sourceId: 'human',
      isRacial: true,
    ),
    CharacterAbilityDefinition(
      id: 'dwarven_resilience',
      name: 'Dwarven Resilience',
      description: 'Resistance a Poison sebzésre, és Advantage a Poisoned állapot elkerülésére vagy megszüntetésére tett mentődobásokra.',
      sourceId: 'dwarf',
      isRacial: true,
    ),
    CharacterAbilityDefinition(
      id: 'darkvision_120',
      name: 'Darkvision',
      description: '120 láb távolságig lát sötétben.',
      sourceId: 'dwarf',
      isRacial: true,
    ),
    CharacterAbilityDefinition(
      id: 'dwarven_toughness',
      name: 'Dwarven Toughness',
      description: 'A Hit Point maximumod 1-gyel nő, majd minden szinten további 1-gyel.',
      sourceId: 'dwarf',
      isRacial: true,
    ),
    CharacterAbilityDefinition(
      id: 'stonecunning',
      name: 'Stonecunning',
      description: 'Kőfelületen 60 láb Tremorsense-t kapsz 10 percre, proficiency bonus alkalommal hosszú pihenőnként.',
      sourceId: 'dwarf',
      isRacial: true,
    ),
    CharacterAbilityDefinition(
      id: 'brave',
      name: 'Brave',
      description: 'Advantage a Frightened állapot elkerülésére vagy megszüntetésére tett mentődobásokra.',
      sourceId: 'halfling',
      isRacial: true,
    ),
    CharacterAbilityDefinition(
      id: 'halfling_nimbleness',
      name: 'Halfling Nimbleness',
      description: 'Áthaladhatsz nálad nagyobb lények terén, de nem fejezheted be ott a mozgásodat.',
      sourceId: 'halfling',
      isRacial: true,
    ),
    CharacterAbilityDefinition(
      id: 'halfling_luck',
      name: 'Luck',
      description: 'A D20 Test 1-es eredményét újradobhatod, és az új eredményt kell használnod.',
      sourceId: 'halfling',
      isRacial: true,
    ),
    CharacterAbilityDefinition(
      id: 'naturally_stealthy',
      name: 'Naturally Stealthy',
      description: 'Elrejtőzhetsz akkor is, ha csak egy nálad legalább egy mérettel nagyobb lény takar.',
      sourceId: 'halfling',
      isRacial: true,
    ),
    CharacterAbilityDefinition(
      id: 'second_wind',
      name: 'Second Wind',
      description: 'Öngyógyítás rövid pihenőnként egyszer.',
      sourceId: 'fighter',
      isRacial: false,
    ),
    CharacterAbilityDefinition(
      id: 'action_surge',
      name: 'Action Surge',
      description: 'Egy további akciót tehetsz, kivéve a Magic akciót; pihenés után visszatér.',
      sourceId: 'fighter',
      isRacial: false,
    ),
    CharacterAbilityDefinition(
      id: 'fighting_style',
      name: 'Fighting Style',
      description: 'Egy Fighting Style featet választasz.',
      sourceId: 'fighter',
      isRacial: false,
    ),
    CharacterAbilityDefinition(
      id: 'weapon_mastery',
      name: 'Weapon Mastery',
      description: 'A jártasságod szerinti fegyverek mastery tulajdonságait használhatod.',
      sourceId: 'fighter',
      isRacial: false,
    ),
    CharacterAbilityDefinition(
      id: 'tactical_mind',
      name: 'Tactical Mind',
      description: 'Sikertelen ability check után Second Wind használatával d10-et adhatsz a dobáshoz.',
      sourceId: 'fighter',
      isRacial: false,
    ),
    CharacterAbilityDefinition(
      id: 'expertise',
      name: 'Expertise',
      description:
          'Két skill proficiency esetén megduplázod a proficiency bonusodat.',
      sourceId: 'rogue',
      isRacial: false,
    ),
    CharacterAbilityDefinition(
      id: 'thieves_cant',
      name: 'Thieves’ Cant',
      description: 'Ismered a Thieves’ Cant nyelvet és egy további nyelvet.',
      sourceId: 'rogue',
      isRacial: false,
    ),
    CharacterAbilityDefinition(
      id: 'rogue_weapon_mastery',
      name: 'Weapon Mastery',
      description: 'Két választott, jártasságod szerinti fegyver mastery tulajdonságait használhatod.',
      sourceId: 'rogue',
      isRacial: false,
    ),
    CharacterAbilityDefinition(
      id: 'cunning_action',
      name: 'Cunning Action',
      description: 'Bonus Actionként Dash, Disengage vagy Hide akciót tehetsz.',
      sourceId: 'rogue',
      isRacial: false,
    ),
    CharacterAbilityDefinition(
      id: 'sneak_attack',
      name: 'Sneak Attack',
      description: 'Előnyös helyzetben extra precíziós sebzést okoz.',
      sourceId: 'rogue',
      isRacial: false,
    ),
    CharacterAbilityDefinition(
      id: 'arcane_recovery',
      name: 'Arcane Recovery',
      description:
          'Pihenés közben visszatölt néhány felhasznált mágikus erőforrást.',
      sourceId: 'wizard',
      isRacial: false,
    ),
    CharacterAbilityDefinition(
      id: 'wizard_spellcasting',
      name: 'Spellcasting',
      description: 'A kasztod spell listájáról varázslatokat készítesz elő és használsz.',
      sourceId: 'wizard',
      isRacial: false,
    ),
    CharacterAbilityDefinition(
      id: 'ritual_adept',
      name: 'Ritual Adept',
      description: 'A spellbookodban lévő Ritual varázslatokat spell slot nélkül is rituáléként használhatod.',
      sourceId: 'wizard',
      isRacial: false,
    ),
    CharacterAbilityDefinition(
      id: 'scholar',
      name: 'Scholar',
      description: 'Egy megfelelő skillben Expertise-t kapsz.',
      sourceId: 'wizard',
      isRacial: false,
    ),
    CharacterAbilityDefinition(
      id: 'divine_order',
      name: 'Divine Order',
      description: 'Protector vagy Thaumaturge szerepet választasz.',
      sourceId: 'cleric',
      isRacial: false,
    ),
    CharacterAbilityDefinition(
      id: 'channel_divinity',
      name: 'Channel Divinity',
      description:
          'Isteni energiát csatornázol Divine Spark vagy Turn Undead hatással.',
      sourceId: 'cleric',
      isRacial: false,
    ),
    CharacterAbilityDefinition(
      id: 'cleric_spellcasting',
      name: 'Spellcasting',
      description:
          'Cleric varázslatokat készítesz elő és használsz Wisdom alapján.',
      sourceId: 'cleric',
      isRacial: false,
    ),
  ];

  static CharacterRaceDefinition raceById(String id) =>
      races.firstWhere((race) => race.id == id);

  static CharacterClassDefinition classById(String id) =>
      classes.firstWhere((characterClass) => characterClass.id == id);

  static CharacterAbilityDefinition abilityById(String id) =>
      abilities.firstWhere((ability) => ability.id == id);

  static List<CharacterAbilityDefinition> racialAbilities(String raceId) =>
      abilities
          .where((ability) => ability.isRacial && ability.sourceId == raceId)
          .toList(growable: false);

  static List<CharacterAbilityDefinition> classAbilities(String classId) =>
      abilities
          .where((ability) => !ability.isRacial && ability.sourceId == classId)
          .toList(growable: false);
}
