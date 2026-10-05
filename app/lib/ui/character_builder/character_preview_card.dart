import 'package:flutter/material.dart';

import '../../core/dnd/character_progression.dart';
import '../../core/dnd/character_stats.dart';

/// Right-hand live physical & combat preview panel for the Character Workbench.
/// Shows real-time recalculations of jump, run speed, HP, AC, AP/mana, and attack bonuses.
class CharacterPreviewCard extends StatelessWidget {
  final CharacterStats preview;
  final int heroLevel;

  const CharacterPreviewCard({
    super.key,
    required this.preview,
    required this.heroLevel,
  });

  @override
  Widget build(BuildContext context) {
    final jumpHeight = preview.maxJumpHeight;
    final jumpVelocity = preview.jumpVelocity.abs();
    final isMaxLevel = heroLevel == CharacterProgression.maxLevel;
    final (platformNotice, noticeColor) = _platformNotice(jumpHeight);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ÉLŐ ELŐNÉZET • STAT-DRIVEN EFFECT',
          style: TextStyle(
            color: Color(0xFF00E5FF),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: _buildTiles(
              jumpHeight,
              jumpVelocity,
              platformNotice,
              noticeColor,
              isMaxLevel,
            ),
          ),
        ),
      ],
    );
  }

  (String, Color) _platformNotice(double jumpHeight) {
    if (jumpHeight >= 125) {
      return (
        '★ Akrobatikus Ugró: könnyen eléri a magaslati hidat!',
        const Color(0xFF69F0AE),
      );
    }
    if (jumpHeight >= 103) {
      return (
        '✓ Képes elérni a lebegő kőplatformokat (103 px)',
        const Color(0xFF00E5FF),
      );
    }
    return (
      '⚠ Alacsony ugrás: nem éri el közvetlenül a kőplatformokat!',
      const Color(0xFFFFB74D),
    );
  }

  List<Widget> _buildTiles(
    double jumpHeight,
    double jumpVelocity,
    String platformNotice,
    Color noticeColor,
    bool isMaxLevel,
  ) {
    return [
      _buildJumpCard(jumpHeight, jumpVelocity, platformNotice, noticeColor),
      const SizedBox(height: 6),
      _buildTile(
        icon: Icons.directions_run,
        iconColor: const Color(0xFF81D4FA),
        title: 'Futási Sebesség (DEX)',
        value: '${preview.moveSpeed.toStringAsFixed(0)} px/s',
        subtitle: 'DEX bónusz: +${preview.dexterityMod * 12} px/s',
      ),
      const SizedBox(height: 6),
      _buildTile(
        icon: Icons.favorite,
        iconColor: const Color(0xFFFF5252),
        title: 'Max Életerő (CON) & AC',
        value: '${preview.maxHp} HP  •  AC ${preview.armorClass}',
        subtitle:
            'Lv $heroLevel Fighter (CON mod: +${preview.constitutionMod})',
      ),
      const SizedBox(height: 6),
      _buildTile(
        icon: Icons.bolt,
        iconColor: const Color(0xFF00E5FF),
        title: 'Mana / Action Points (AP)',
        value: '${preview.maxMana} AP Pool',
        subtitle:
            'Tervezés: ${(preview.maxMana / 25).floor()} Slash csapás / kör',
      ),
      const SizedBox(height: 6),
      _buildTile(
        icon: Icons.flash_on,
        iconColor: const Color(0xFFFFD54F),
        title: 'Közelharci Támadás (STR)',
        value: '+${preview.meleeAttackBonus} to Hit',
        subtitle:
            'Proficiency (+${preview.proficiencyBonus}) + STR (+${preview.strengthMod})',
      ),
      if (isMaxLevel) ...[
        const SizedBox(height: 8),
        _buildLevel20SummaryCard(),
      ],
    ];
  }

  Widget _buildJumpCard(
    double jumpHeight,
    double jumpVelocity,
    String platformNotice,
    Color noticeColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF252136),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: noticeColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_upward,
                      color: Color(0xFF00E5FF),
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Ugrásmagasság (STR)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${jumpHeight.toStringAsFixed(0)} px (${jumpVelocity.toStringAsFixed(0)} px/s)',
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            platformNotice,
            style: TextStyle(
              color: noticeColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevel20SummaryCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF281E38),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD54F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.military_tech, color: Color(0xFFFFD54F), size: 16),
              SizedBox(width: 6),
              Text(
                '20. SZINTŰ HATÁS ELEMZÉS:',
                style: TextStyle(
                  color: Color(0xFFFFD54F),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '• ÉLETERŐ (HP): 14 -> ${preview.maxHp} HP (+1500% - LEGNAGYOBB HATÁS!)\n'
            '• MANA / AP: 100 -> ${preview.maxMana} AP (+100% - Dupla akciókapacitás)\n'
            '• UGRÁS: 86 px -> ${preview.maxJumpHeight.toStringAsFixed(0)} px (+60% magasság)\n'
            '• SEBESSÉG: 180 -> ${preview.moveSpeed.toStringAsFixed(0)} px/s (+33% sprint)',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 10,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF221E32),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF332A47)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 9,
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
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
