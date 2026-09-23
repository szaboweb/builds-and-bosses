import 'package:flutter/material.dart';

import '../core/campaign/campaign_blueprint.dart';
import '../core/config/game_rules_config.dart';
import '../core/dnd/character_stats.dart';
import '../game/tactical_game.dart';

/// Gothic-themed RPG Character Builder / Tervezőasztal Overlay.
/// Allows players to allocate attributes using the 28-point buy system,
/// with live real-time feedback on jump height, run speed, HP, and combat power.
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

  late Map<String, int> _scores;
  String _heroName = 'Fighter';
  CampaignLevelMode _levelMode = CampaignLevelMode.levelUp;

  int get _heroLevel => _progression.expectedHeroLevel(_levelMode);

  @override
  void initState() {
    super.initState();
    final currentStats = widget.game.player.stats;
    _heroName = currentStats.name;
    _scores = {
      'STR': currentStats.strength,
      'DEX': currentStats.dexterity,
      'CON': currentStats.constitution,
      'INT': currentStats.intelligence,
      'WIS': currentStats.wisdom,
      'CHA': currentStats.charisma,
    };
  }

  int get _remainingPoints => _pointBuy.remainingPoints(_scores);

  CharacterStats _buildPreviewStats() {
    final str = _scores['STR'] ?? 10;
    final dex = _scores['DEX'] ?? 10;
    final con = _scores['CON'] ?? 10;
    final intelligence = _scores['INT'] ?? 10;
    final wis = _scores['WIS'] ?? 10;
    final cha = _scores['CHA'] ?? 10;

    final conMod = ((con - 10) / 2).floor();
    final maxHp = GameRulesConfig.standard.combat.calculateMaxHp(
      _heroLevel,
      conMod,
      baseHpOverride: 12,
    );

    return CharacterStats(
      name: _heroName,
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

  void _increment(String attr) {
    if (_pointBuy.canIncrease(_scores, attr)) {
      setState(() {
        _scores[attr] = (_scores[attr] ?? 8) + 1;
      });
    }
  }

  void _decrement(String attr) {
    if (_pointBuy.canDecrease(_scores, attr)) {
      setState(() {
        _scores[attr] = (_scores[attr] ?? 8) - 1;
      });
    }
  }

  void _resetToDefault() {
    setState(() {
      _scores = {
        'STR': 16,
        'DEX': 12,
        'CON': 14,
        'INT': 10,
        'WIS': 12,
        'CHA': 10,
      };
    });
  }

  void _applyBuild() {
    final newStats = _buildPreviewStats();
    final blueprint = _progression.firstBossBlueprint(
      levelMode: _levelMode,
      classLevels: {'Fighter': _heroLevel},
      abilityScores: _scores,
    );
    if (!blueprint.validate(_progression).isValid) return;
    widget.game.applyHeroBuild(newStats, blueprint: blueprint);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _buildPreviewStats();
    final jumpHeight = preview.maxJumpHeight;
    final jumpVelocity = preview.jumpVelocity.abs();
    final blueprint = _progression.firstBossBlueprint(
      levelMode: _levelMode,
      classLevels: {'Fighter': _heroLevel},
      abilityScores: _scores,
    );
    final blueprintIsValid = blueprint.validate(_progression).isValid;

    // Clearance evaluation for the arena platforms
    final String platformNotice;
    final Color noticeColor;
    if (jumpHeight >= 125) {
      platformNotice = '★ Akrobatikus Ugró: könnyen eléri a magaslati hidat!';
      noticeColor = const Color(0xFF69F0AE);
    } else if (jumpHeight >= 103) {
      platformNotice = '✓ Képes elérni a lebegő kőplatformokat (103 px)';
      noticeColor = const Color(0xFF00E5FF);
    } else {
      platformNotice =
          '⚠ Alacsony ugrás: nem éri el közvetlenül a kőplatformokat!';
      noticeColor = const Color(0xFFFFB74D);
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Container(
          width: 820,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF14121E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF3B2F50), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.25),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF261D36),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.build_circle,
                          color: Color(0xFFFFD54F),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TERVEZŐASZTAL • CHARACTER WORKBENCH',
                            style: TextStyle(
                              color: Color(0xFFFFD54F),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.4,
                            ),
                          ),
                          Text(
                            'D&D 5e Stat-Driven & Config-Driven Karakterkészítő',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _remainingPoints >= 0
                          ? const Color(0xFF1B2E24)
                          : const Color(0xFF3E1B1B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _remainingPoints >= 0
                            ? const Color(0xFF00E676)
                            : const Color(0xFFFF5252),
                      ),
                    ),
                    child: Text(
                      'Pontkeret: $_remainingPoints / ${_pointBuy.totalBudget} pont',
                      style: TextStyle(
                        color: _remainingPoints >= 0
                            ? const Color(0xFF00E676)
                            : const Color(0xFFFF5252),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              const Divider(color: Color(0xFF2E2640), height: 1),
              const SizedBox(height: 18),

              Row(
                children: [
                  const Text(
                    'ELSŐ BOSS KAMPÁNYMÓD',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ToggleButtons(
                    isSelected: [
                      _levelMode == CampaignLevelMode.levelDown,
                      _levelMode == CampaignLevelMode.levelUp,
                    ],
                    onPressed: (index) {
                      setState(() {
                        _levelMode = index == 0
                            ? CampaignLevelMode.levelDown
                            : CampaignLevelMode.levelUp;
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    selectedColor: Colors.black,
                    fillColor: const Color(0xFFFFD54F),
                    color: Colors.white70,
                    constraints: const BoxConstraints(
                      minHeight: 34,
                      minWidth: 116,
                    ),
                    children: const [
                      Text('LEVEL DOWN • Lv1'),
                      Text('LEVEL UP • Lv2'),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'Boss Lv${CampaignProgression.firstBossLevel} • Fighter Lv$_heroLevel',
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Main Content: 2 Columns (Left: Point-Buy Attributes, Right: Live Physical & Combat Preview)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Attribute Point Allocation
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ALAP ÉRTÉKEK KIOSZTÁSA (POINT BUY)',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ..._scores.keys.map((attr) {
                          return _buildAttributeRow(attr, _scores[attr] ?? 10);
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Right Column: Live Stat-Driven Physics & Combat Preview
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1929),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF382F4E)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ÉLŐ ELŐNÉZET • STAT-DRIVEN EFFECT',
                            style: TextStyle(
                              color: Color(0xFF00E5FF),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Dynamic Jump Card (Strength Effect)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF252136),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: noticeColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.arrow_upward,
                                          color: Color(0xFF00E5FF),
                                          size: 18,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Ugrásmagasság (STR)',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${jumpHeight.toStringAsFixed(0)} px peak  (${jumpVelocity.toStringAsFixed(0)} px/s)',
                                      style: const TextStyle(
                                        color: Color(0xFF00E5FF),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  platformNotice,
                                  style: TextStyle(
                                    color: noticeColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Dynamic Run Speed Card (Dexterity Effect)
                          _buildPreviewStatTile(
                            icon: Icons.directions_run,
                            iconColor: const Color(0xFF81D4FA),
                            title: 'Futási Sebesség (DEX)',
                            value:
                                '${preview.moveSpeed.toStringAsFixed(0)} px/s',
                            subtitle:
                                'DEX bónusz: +${preview.dexterityMod * 12} px/s',
                          ),

                          const SizedBox(height: 10),

                          // Combat Stats Card (HP, AC, Attack Bonus)
                          _buildPreviewStatTile(
                            icon: Icons.favorite,
                            iconColor: const Color(0xFFFF5252),
                            title: 'Max Életerő (CON) & AC',
                            value:
                                '${preview.maxHp} HP  •  AC ${preview.armorClass}',
                            subtitle:
                                'Level $_heroLevel Fighter (CON mod: +${preview.constitutionMod})',
                          ),

                          const SizedBox(height: 10),

                          // Melee Strike Card (Strength Mod)
                          _buildPreviewStatTile(
                            icon: Icons.flash_on,
                            iconColor: const Color(0xFFFFD54F),
                            title: 'Közelharci Támadás (STR)',
                            value: '+${preview.meleeAttackBonus} to Hit',
                            subtitle:
                                'Sebzés: 1d8 + ${preview.strengthMod} slashing',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // Bottom Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: _resetToDefault,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('ALAPHELYZET'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Color(0xFF433959)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: widget.game.closeCharacterBuilder,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Color(0xFF433959)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('MÉGSE [ESC]'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _remainingPoints >= 0 && blueprintIsValid
                        ? _applyBuild
                        : null,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('BUILD ALKALMAZÁSA & ARÉNA'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF332948),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttributeRow(String attributeKey, int score) {
    final mod = ((score - 10) / 2).floor();
    final modString = mod >= 0 ? '+$mod' : '$mod';
    final canInc = _pointBuy.canIncrease(_scores, attributeKey);
    final canDec = _pointBuy.canDecrease(_scores, attributeKey);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1A2D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF312844)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              attributeKey,
              style: const TextStyle(
                color: Color(0xFFFFD54F),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            modString,
            style: TextStyle(
              color: mod >= 0
                  ? const Color(0xFF69F0AE)
                  : const Color(0xFFFF5252),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                color: canDec ? const Color(0xFFFF8A80) : Colors.white24,
                onPressed: canDec ? () => _decrement(attributeKey) : null,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              Container(
                width: 34,
                alignment: Alignment.center,
                child: Text(
                  '$score',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                color: canInc ? const Color(0xFF00E5FF) : Colors.white24,
                onPressed: canInc ? () => _increment(attributeKey) : null,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewStatTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF221E32),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF332A47)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
