import 'package:flutter/material.dart';
import '../core/actions/game_action.dart';
import '../game/tactical_game.dart';

/// Tactical Mode Action Bar Overlay:
/// Displays the AP (Action Points) gauge, skill selectors, queued timeline chips,
/// and Tactical Action execution triggers.
class ActionBarOverlay extends StatelessWidget {
  final TacticalModeGame game;

  const ActionBarOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 20,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          game.actionQueue,
          game.selectedActionNotifier,
        ]),
        builder: (context, _) {
          final maxAP = game.actionQueue.maxAP;
          final remaining = game.actionQueue.remainingAP;
          final ratio = (remaining / maxAP).clamp(0.0, 1.0);

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF10131E).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. AP Gauge Bar
                Row(
                  children: [
                    const Icon(Icons.bolt, color: Color(0xFF00E5FF), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'ACTION POINTS',
                      style: TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$remaining / $maxAP AP',
                      style: TextStyle(
                        color: remaining > 25
                            ? const Color(0xFFE0F7FA)
                            : const Color(0xFFFF5252),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      ratio > 0.3
                          ? const Color(0xFF00E5FF)
                          : const Color(0xFFFF5252),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Skill Palette (Selectable Action Types)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSkillCard(
                      type: ActionType.slash,
                      title: 'HARC (SLASH)',
                      cost: 25,
                      icon: Icons.sports_kabaddi,
                      isSelected:
                          game.selectedActionNotifier.value == ActionType.slash,
                      onTap: () => game.selectedActionNotifier.value =
                          ActionType.slash,
                    ),
                    const SizedBox(width: 12),
                    _buildSkillCard(
                      type: ActionType.move,
                      title: 'MOVE',
                      cost: 15,
                      icon: Icons.directions_walk,
                      isSelected:
                          game.selectedActionNotifier.value == ActionType.move,
                      onTap: () => game.selectedActionNotifier.value =
                          ActionType.move,
                    ),
                    const SizedBox(width: 12),
                    _buildSkillCard(
                      type: ActionType.dash,
                      title: 'DASH',
                      cost: 20,
                      icon: Icons.fast_forward,
                      isSelected:
                          game.selectedActionNotifier.value == ActionType.dash,
                      onTap: () => game.selectedActionNotifier.value =
                          ActionType.dash,
                    ),
                    const SizedBox(width: 12),
                    _buildSkillCard(
                      type: ActionType.heal,
                      title: 'WIND',
                      cost: 30,
                      icon: Icons.favorite,
                      isSelected:
                          game.selectedActionNotifier.value == ActionType.heal,
                      onTap: () {
                        game.selectedActionNotifier.value = ActionType.heal;
                        // Directly queue Second Wind heal if tapped
                        game.actionQueue.tryAdd(HealAction());
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 3. Planned Queue Timeline & Buttons
                Row(
                  children: [
                    // Queue list or placeholder
                    Expanded(
                      child: game.actionQueue.isEmpty
                          ? const Text(
                              'Kattints a csapáshoz vagy lépéshez...',
                              style: TextStyle(
                                color: Colors.white54,
                                fontStyle: FontStyle.italic,
                                fontSize: 13,
                              ),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: List.generate(
                                  game.actionQueue.actions.length,
                                  (index) {
                                    final action = game.actionQueue.actions[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: Chip(
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        backgroundColor:
                                            const Color(0xFF1E2638),
                                        label: Text(
                                          '${index + 1}. ${action.name} (${action.apCost} AP)',
                                          style: const TextStyle(
                                            color: Color(0xFF00E5FF),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        onDeleted: () =>
                                            game.actionQueue.removeAt(index),
                                        deleteIconColor:
                                            Colors.redAccent.shade100,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(width: 12),

                    // Undo Button
                    IconButton(
                      tooltip: 'Undo last step',
                      icon: const Icon(Icons.undo, color: Colors.white70),
                      onPressed:
                          game.actionQueue.isNotEmpty ? () => game.actionQueue.undo() : null,
                    ),

                    // Cancel Button
                    TextButton(
                      onPressed: () => game.cancelPlanning(),
                      child: const Text(
                        'CANCEL [ENTER]',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Execute Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: game.actionQueue.isNotEmpty
                          ? () => game.executePlan()
                          : null,
                      icon: const Icon(Icons.play_arrow, size: 20),
                      label: const Text(
                        'EXECUTE [SPACE]',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkillCard({
    required ActionType type,
    required String title,
    required int cost,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00E5FF).withValues(alpha: 0.18)
              : const Color(0xFF161C2C),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00E5FF)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF00E5FF) : Colors.white70,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$cost AP',
              style: TextStyle(
                color: isSelected ? const Color(0xFF00E5FF) : Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
