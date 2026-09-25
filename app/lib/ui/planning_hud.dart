import 'package:flutter/material.dart';

import '../core/actions/game_action.dart';
import '../game/tactical_game.dart';

/// Top Status HUD overlay displaying player stats, boss stats, and Tactical Mode trigger.
class PlanningHUD extends StatelessWidget {
  final TacticalModeGame game;

  const PlanningHUD({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: ValueListenableBuilder<GamePhase>(
        valueListenable: game.phaseNotifier,
        builder: (context, phase, _) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Player Card
              _buildPlayerCard(),

              const SizedBox(width: 8),

              ValueListenableBuilder<ActionType>(
                valueListenable: game.selectedActionNotifier,
                builder: (context, mode, _) => _buildCombatModeIndicator(mode),
              ),

              const Spacer(),

              // Phase Banner
              _buildPhaseBanner(phase),

              const Spacer(),

              // Enemy Card
              _buildEnemyCard(),

              const SizedBox(width: 12),

              // Character Workbench (Tervezőasztal) Button
              if (phase == GamePhase.realtime) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFD54F),
                    side: const BorderSide(
                      color: Color(0xFFFFD54F),
                      width: 1.5,
                    ),
                    backgroundColor: const Color(0xFF1C1829)
                        .withValues(alpha: 0.8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => game.openCharacterBuilder(),
                  icon: const Icon(
                    Icons.build,
                    size: 18,
                    color: Color(0xFFFFD54F),
                  ),
                  label: const Text(
                    'TERVEZŐASZTAL [B]',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Quick Tactical Mode Button
              if (phase == GamePhase.realtime)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 6,
                  ),
                  onPressed: () => game.startPlanning(),
                  icon: const Icon(Icons.flash_on, size: 20),
                  label: const Text(
                    'TACTICAL MODE [ENTER]',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              if (phase == GamePhase.realtime)
                IconButton(
                  tooltip: 'Auto harc: fix pipeline futtatása [F]',
                  onPressed: game.startAutoCombat,
                  icon: const Icon(Icons.smart_toy, color: Color(0xFFFF8A65)),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlayerCard() {
    final stats = game.player.stats;
    final hpRatio = (stats.currentHp / stats.maxHp).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF10131E).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.shield, color: Color(0xFF64B5F6), size: 16),
              const SizedBox(width: 6),
              Text(
                '${stats.name.toUpperCase()} (Lvl ${stats.level})',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade800,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'AC ${stats.armorClass}',
                  style: const TextStyle(
                    color: Color(0xFF90CAF9),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2733),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'STR ${stats.strength} (${stats.maxJumpHeight.toStringAsFixed(0)}px)',
                  style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 100,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: hpRatio,
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF4CAF50),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${stats.currentHp}/${stats.maxHp} HP',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnemyCard() {
    final enemyStats = game.enemy.stats;
    final hpRatio = (enemyStats.currentHp / enemyStats.maxHp).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF10131E).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade900,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'AC ${enemyStats.armorClass}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                enemyStats.name.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFFFF8A80),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.warning_amber,
                color: Color(0xFFFF5252),
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${enemyStats.currentHp}/${enemyStats.maxHp} HP',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: hpRatio,
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFE53935),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCombatModeIndicator(ActionType mode) {
    final label = switch (mode) {
      ActionType.slash => 'MELEE',
      ActionType.ranged => 'RANGED',
      ActionType.spell => 'SPELL',
      _ => 'COMBAT',
    };
    final icon = switch (mode) {
      ActionType.slash => Icons.sports_kabaddi,
      ActionType.ranged => Icons.arrow_forward,
      ActionType.spell => Icons.auto_awesome,
      _ => Icons.shield,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2733).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF00E5FF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF00E5FF), size: 16),
          const SizedBox(width: 6),
          Text(
            'MODE: $label',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseBanner(GamePhase phase) {
    Color color;
    String text;
    IconData icon;

    switch (phase) {
      case GamePhase.realtime:
        color = Colors.white54;
        text = 'REALTIME PLATFORMER (A/D, SPACE)';
        icon = Icons.timer_outlined;
        break;
      case GamePhase.planning:
        color = const Color(0xFF00E5FF);
        text = 'PLANNING PHASE [TIME FROZEN]';
        icon = Icons.pause_circle_outline;
        break;
      case GamePhase.executing:
        color = const Color(0xFFFFD54F);
        text = 'EXECUTING ACTIONS...';
        icon = Icons.fast_forward;
        break;
      case GamePhase.cooldown:
        color = Colors.grey;
        text = 'RECOVERY';
        icon = Icons.refresh;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
