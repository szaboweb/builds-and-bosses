import 'package:flutter/material.dart';

import '../../core/dnd/character_progression.dart';
import '../widgets/rpg_stat_badge_widget.dart';

/// Card component allowing the player to select character level (1 to 20),
/// displaying D&D 5e Proficiency Bonus, Ability Score Improvements (ASI),
/// and quick-select buttons for ASI threshold levels.
class LevelProgressionCard extends StatelessWidget {
  final int currentLevel;
  final ValueChanged<int> onLevelChanged;

  const LevelProgressionCard({
    super.key,
    required this.currentLevel,
    required this.onLevelChanged,
  });

  @override
  Widget build(BuildContext context) {
    final profBonus = CharacterProgression.proficiencyBonusFor(currentLevel);
    final asiPoints = CharacterProgression.asiPointsForLevel(currentLevel);
    final isMaxLevel = currentLevel == CharacterProgression.maxLevel;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1727),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMaxLevel ? const Color(0xFFFFD54F) : const Color(0xFF3B2F50),
          width: isMaxLevel ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(profBonus, asiPoints),
          const SizedBox(height: 10),
          _buildControlsRow(context, isMaxLevel),
          if (isMaxLevel) ...[
            const SizedBox(height: 8),
            _buildMaxLevelBanner(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(int profBonus, int asiPoints) {
    return Row(
      children: [
        const Icon(Icons.stars, color: Color(0xFFFFD54F), size: 18),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'KARAKTER SZINT & D&D 5E FEJLŐDÉS',
            style: TextStyle(
              color: Color(0xFFFFD54F),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        RpgStatBadgeWidget(
          label: 'Proficiency: +$profBonus',
          textColor: const Color(0xFF64B5F6),
        ),
        const SizedBox(width: 6),
        RpgStatBadgeWidget(
          label: 'ASI Pontok: +$asiPoints',
          textColor: const Color(0xFF00E676),
        ),
      ],
    );
  }

  Widget _buildControlsRow(BuildContext context, bool isMaxLevel) {
    return Row(
      children: [
        _buildStepperButton(
          icon: Icons.remove_circle,
          enabled: currentLevel > CharacterProgression.minLevel,
          color: const Color(0xFFFF8A80),
          onPressed: () => onLevelChanged(currentLevel - 1),
        ),
        _buildLevelIndicator(isMaxLevel),
        _buildStepperButton(
          icon: Icons.add_circle,
          enabled: currentLevel < CharacterProgression.maxLevel,
          color: const Color(0xFF00E5FF),
          onPressed: () => onLevelChanged(currentLevel + 1),
        ),
        const SizedBox(width: 12),
        Expanded(child: _buildSlider(context)),
        for (final lvl in [1, 4, 8, 12, 16]) ...[
          _buildQuickLevelButton(lvl),
          const SizedBox(width: 4),
        ],
        _buildQuickLevelButton(20, label: '20 MAX'),
      ],
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required bool enabled,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 22),
      color: enabled ? color : Colors.white24,
      onPressed: enabled ? onPressed : null,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  Widget _buildLevelIndicator(bool isMaxLevel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF261F38),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMaxLevel ? const Color(0xFFFFD54F) : const Color(0xFF4B3A67),
        ),
      ),
      child: Text(
        'SZINT $currentLevel',
        style: TextStyle(
          color: isMaxLevel ? const Color(0xFFFFD54F) : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildSlider(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: const Color(0xFF7C4DFF),
        inactiveTrackColor: const Color(0xFF2E2640),
        thumbColor: const Color(0xFFFFD54F),
        overlayColor: const Color(0xFFFFD54F).withValues(alpha: 0.2),
        trackHeight: 4,
      ),
      child: Slider(
        value: currentLevel.toDouble(),
        min: CharacterProgression.minLevel.toDouble(),
        max: CharacterProgression.maxLevel.toDouble(),
        divisions: 19,
        label: 'Szint: $currentLevel',
        onChanged: (val) => onLevelChanged(val.round()),
      ),
    );
  }

  Widget _buildMaxLevelBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF332A15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFFD54F), width: 1),
      ),
      child: const Row(
        children: [
          Icon(Icons.workspace_premium, color: Color(0xFFFFD54F), size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '20. SZINTŰ CSÚCSHATÁS AKTÍV: Legnagyobb növekedés: HP (+1500%) & Dupla Mana/AP (200 AP), +11 Támadóbónusz!',
              style: TextStyle(
                color: Color(0xFFFFD54F),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLevelButton(int level, {String? label}) {
    final isSelected = currentLevel == level;
    return InkWell(
      onTap: () => onLevelChanged(level),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7C4DFF) : const Color(0xFF261F38),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFFD54F)
                : const Color(0xFF4A3866),
          ),
        ),
        child: Text(
          label ?? 'Lv $level',
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
