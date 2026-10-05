import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/campaign/campaign_blueprint.dart';
import '../core/config/game_rules_config.dart';
import '../core/dnd/character_catalog.dart';
import '../core/dnd/character_progression.dart';
import '../core/dnd/character_stats.dart';
import '../game/components/player_component.dart';
import '../game/tactical_game.dart';
import 'character_builder/attribute_stepper_widget.dart';
import 'character_builder/character_preview_card.dart';
import 'character_builder/level_progression_card.dart';

/// Gothic-themed RPG Character Builder / Tervezőasztal Overlay.
/// Allows players to allocate attributes using the 2024 27-point buy system
/// and D&D 5e Ability Score Improvements (ASI) across levels 1 to 20,
/// with live real-time feedback on jump height, run speed, HP, and AP/mana.
class CharacterBuilderOverlay extends StatefulWidget {
  final TacticalModeGame game;

  const CharacterBuilderOverlay({super.key, required this.game});

  @override
  State<CharacterBuilderOverlay> createState() =>
      _CharacterBuilderOverlayState();
}

class _CharacterBuilderOverlayState extends State<CharacterBuilderOverlay> {
  final PointBuyConfig _pointBuy = GameRulesConfig.standard.pointBuy;
  static const CampaignProgression _progression = CampaignProgression();

  int _heroLevel = 3;
  String _heroName = 'Fighter';
  final String _selectedRaceId = 'human';
  final String _selectedClassId = 'fighter';
  final Set<String> _selectedAbilityIds = <String>{};
  List<String> _characterSheets = const [];

  late Map<String, int> _baseScores;
  late Map<String, int> _asiAllocations;

  static const List<String> _attributeKeys = [
    'STR',
    'DEX',
    'CON',
    'INT',
    'WIS',
    'CHA',
  ];

  static const Map<String, String> _attributeLabels = {
    'STR': 'Erő',
    'DEX': 'Ügyesség',
    'CON': 'Állóképesség',
    'INT': 'Intelligencia',
    'WIS': 'Bölcsesség',
    'CHA': 'Karizma',
  };

  static const Map<String, String> _attributeDescriptions = {
    'STR': 'Ugrásmagasság, lökés, közelharci támadás',
    'DEX': 'Futási sebesség, kitérés, mozgékonyság',
    'CON': 'Maximális életerő (HP)',
    'INT': 'Varázslat hatásfok, Mana/AP bónusz',
    'WIS': 'Érzékelés, Mana/AP bónusz',
    'CHA': 'Társalgás, vezetés, akarat',
  };

  @override
  void initState() {
    super.initState();
    final currentStats = widget.game.player.stats;
    _heroName = currentStats.name;
    _heroLevel = currentStats.level.clamp(
      CharacterProgression.minLevel,
      CharacterProgression.maxLevel,
    );
    _selectedAbilityIds.addAll(['second_wind', 'resourceful', 'versatile']);

    _initScoresFromStats(currentStats);
    unawaited(_loadCharacterSheets());
  }

  void _initScoresFromStats(CharacterStats stats) {
    _baseScores = {
      'STR': min(15, max(8, stats.strength)),
      'DEX': min(15, max(8, stats.dexterity)),
      'CON': min(15, max(8, stats.constitution)),
      'INT': min(15, max(8, stats.intelligence)),
      'WIS': min(15, max(8, stats.wisdom)),
      'CHA': min(15, max(8, stats.charisma)),
    };
    _asiAllocations = {
      'STR': max(0, stats.strength - 15),
      'DEX': max(0, stats.dexterity - 15),
      'CON': max(0, stats.constitution - 15),
      'INT': max(0, stats.intelligence - 15),
      'WIS': max(0, stats.wisdom - 15),
      'CHA': max(0, stats.charisma - 15),
    };
    _clampAsiToBudget();
  }

  int _totalScoreFor(String key) {
    final base = _baseScores[key] ?? 10;
    final asi = _asiAllocations[key] ?? 0;
    return min(20, base + asi);
  }

  Map<String, int> get _currentTotalScores => {
    for (final key in _attributeKeys) key: _totalScoreFor(key),
  };

  int get _totalAsiBudget => CharacterProgression.asiPointsForLevel(
    _heroLevel,
    classId: _selectedClassId,
  );

  int get _spentAsiPoints =>
      _asiAllocations.values.fold(0, (sum, val) => sum + val);

  int get _remainingAsiPoints => max(0, _totalAsiBudget - _spentAsiPoints);

  int get _remainingPointBuy => _pointBuy.remainingPoints(_baseScores);

  void _clampAsiToBudget() {
    while (_spentAsiPoints > _totalAsiBudget) {
      for (final key in _attributeKeys.reversed) {
        if ((_asiAllocations[key] ?? 0) > 0) {
          _asiAllocations[key] = _asiAllocations[key]! - 1;
          break;
        }
      }
    }
  }

  void _onLevelChanged(int newLevel) {
    setState(() {
      _heroLevel = newLevel.clamp(
        CharacterProgression.minLevel,
        CharacterProgression.maxLevel,
      );
      _clampAsiToBudget();
    });
  }

  void _increment(String attr) {
    setState(() {
      final currentTotal = _totalScoreFor(attr);
      if (currentTotal >= 20) return;

      final currentBase = _baseScores[attr] ?? 8;
      if (currentBase < 15 && _pointBuy.canIncrease(_baseScores, attr)) {
        _baseScores[attr] = currentBase + 1;
      } else if (_remainingAsiPoints > 0) {
        _asiAllocations[attr] = (_asiAllocations[attr] ?? 0) + 1;
      }
    });
  }

  void _decrement(String attr) {
    setState(() {
      final currentAsi = _asiAllocations[attr] ?? 0;
      if (currentAsi > 0) {
        _asiAllocations[attr] = currentAsi - 1;
      } else if (_pointBuy.canDecrease(_baseScores, attr)) {
        _baseScores[attr] = (_baseScores[attr] ?? 8) - 1;
      }
    });
  }

  bool _canIncrement(String attr) {
    final currentTotal = _totalScoreFor(attr);
    if (currentTotal >= 20) return false;
    final currentBase = _baseScores[attr] ?? 8;
    if (currentBase < 15 && _pointBuy.canIncrease(_baseScores, attr)) {
      return true;
    }
    return _remainingAsiPoints > 0;
  }

  bool _canDecrement(String attr) {
    final currentAsi = _asiAllocations[attr] ?? 0;
    if (currentAsi > 0) return true;
    return _pointBuy.canDecrease(_baseScores, attr);
  }

  Future<void> _loadCharacterSheets() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final sheets =
        manifest
            .listAssets()
            .where(
              (asset) =>
                  asset.startsWith('assets/images/characters/') &&
                  asset.endsWith('.png') &&
                  asset.contains('walk13_'),
            )
            .map((asset) => asset.substring('assets/images/'.length))
            .toList()
          ..sort();
    if (!mounted) return;
    setState(() => _characterSheets = sheets);
  }

  Future<void> _selectCharacterSheet(String path) async {
    if (path != PlayerComponent.godotFighterSheetPath &&
        widget.game.player.equippedItems.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A Godot-felszerelés a fighterhez illeszkedik. '
            'Másik sprite választása előtt vedd le a felszerelést.',
          ),
        ),
      );
      return;
    }
    final success = await widget.game.player.setCharacterAppearance(path);
    if (!success || !mounted) return;
    setState(() {});
  }

  void _changeCharacterSheet(String? value) {
    if (value != null) {
      unawaited(_selectCharacterSheet(value));
    }
  }

  void _resetToDefault() {
    setState(() {
      _heroLevel = 3;
      _baseScores = {
        'STR': 15,
        'DEX': 12,
        'CON': 13,
        'INT': 10,
        'WIS': 12,
        'CHA': 10,
      };
      _asiAllocations = {
        'STR': 1,
        'DEX': 0,
        'CON': 1,
        'INT': 0,
        'WIS': 0,
        'CHA': 0,
      };
      _clampAsiToBudget();
    });
  }

  CharacterStats _buildPreviewStats() {
    final scores = _currentTotalScores;
    final str = scores['STR'] ?? 10;
    final dex = scores['DEX'] ?? 10;
    final con = scores['CON'] ?? 10;
    final intelligence = scores['INT'] ?? 10;
    final wis = scores['WIS'] ?? 10;
    final cha = scores['CHA'] ?? 10;

    final conMod = ((con - 10) / 2).floor();

    final maxHp = CharacterProgression.calculateMaxHp(
      _heroLevel,
      conMod,
      baseHp: 12,
      hpPerLevel: 6,
    );

    return CharacterStats(
      name: _heroName,
      classId: _selectedClassId,
      raceId: _selectedRaceId,
      level: _heroLevel,
      maxHp: maxHp,
      armorClass: 16,
      strength: str,
      dexterity: dex,
      constitution: con,
      intelligence: intelligence,
      wisdom: wis,
      charisma: cha,
      config: GameRulesConfig.standard,
    );
  }

  void _applyBuild() {
    final newStats = _buildPreviewStats();
    final blueprint = _progression.firstBossBlueprint(
      levelMode: CampaignLevelMode.custom,
      customLevel: _heroLevel,
      classLevels: {
        CharacterCatalog.classById(_selectedClassId).name: _heroLevel,
      },
      abilityScores: _currentTotalScores,
      raceId: _selectedRaceId,
      selectedAbilityIds: _selectedAbilityIds.toList(),
    );
    widget.game.applyHeroBuild(newStats, blueprint: blueprint);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _buildPreviewStats();

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Container(
          width: 860,
          constraints: const BoxConstraints(maxHeight: 720),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF14121E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF3B2F50), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.25),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const SizedBox(height: 14),
              LevelProgressionCard(
                currentLevel: _heroLevel,
                onLevelChanged: _onLevelChanged,
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Attribute Allocation
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'STATOK KIOSZTÁSA (POINT BUY & ASI)',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              Text(
                                'ASI: $_remainingAsiPoints/$_totalAsiBudget | PB: $_remainingPointBuy/27',
                                style: TextStyle(
                                  color: _remainingPointBuy >= 0
                                      ? const Color(0xFF00E676)
                                      : const Color(0xFFFF5252),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                for (final key in _attributeKeys)
                                  AttributeStepperWidget(
                                    attributeKey: key,
                                    label: _attributeLabels[key] ?? key,
                                    effectDescription:
                                        _attributeDescriptions[key] ?? '',
                                    state: AttributeStepperState(
                                      score: _totalScoreFor(key),
                                      canIncrement: _canIncrement(key),
                                      canDecrement: _canDecrement(key),
                                      onIncrement: () => _increment(key),
                                      onDecrement: () => _decrement(key),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    // Right Column: Live Physical & Combat Preview
                    Expanded(
                      flex: 5,
                      child: CharacterPreviewCard(
                        preview: preview,
                        heroLevel: _heroLevel,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD54F).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFD54F)),
          ),
          child: const Icon(Icons.build, color: Color(0xFFFFD54F), size: 24),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TERVEZŐASZTAL • CHARACTER WORKBENCH',
              style: TextStyle(
                color: Color(0xFFFFD54F),
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              'D&D 5e Stat-Driven & Config-Driven Karakterkészítő (Szint 1-20)',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _remainingPointBuy >= 0
                ? const Color(0xFF1B2E24)
                : const Color(0xFF3E1B1B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _remainingPointBuy >= 0
                  ? const Color(0xFF00E676)
                  : const Color(0xFFFF5252),
            ),
          ),
          child: Text(
            'PB: $_remainingPointBuy / 27 pont',
            style: TextStyle(
              color: _remainingPointBuy >= 0
                  ? const Color(0xFF00E676)
                  : const Color(0xFFFF5252),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Row(
      children: [
        if (_characterSheets.length > 1) ...[
          const Text(
            'Sprite:',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 140,
            child: DropdownButton<String>(
              isExpanded: true,
              dropdownColor: const Color(0xFF1B1727),
              value:
                  _characterSheets.contains(
                    widget.game.player.characterSheetPath,
                  )
                  ? widget.game.player.characterSheetPath
                  : null,
              hint: const Text('Sprite', style: TextStyle(fontSize: 11)),
              items: [
                for (final sheet in _characterSheets)
                  DropdownMenuItem(
                    value: sheet,
                    child: Text(
                      sheet.split('/').length > 1 ? sheet.split('/')[1] : sheet,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
              onChanged: _changeCharacterSheet,
            ),
          ),
        ],
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _resetToDefault,
          icon: const Icon(Icons.refresh, size: 14),
          label: const Text('ALAPHELYZET', style: TextStyle(fontSize: 11)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Color(0xFF433959)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: widget.game.closeCharacterBuilder,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Color(0xFF433959)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          child: const Text('MÉGSE [ESC]', style: TextStyle(fontSize: 11)),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _remainingPointBuy >= 0 ? _applyBuild : null,
          icon: const Icon(Icons.check, size: 16),
          label: const Text(
            'BUILD ALKALMAZÁSA & ARÉNA',
            style: TextStyle(fontSize: 11),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C4DFF),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF332948),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
