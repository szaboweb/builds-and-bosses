import 'package:flutter/material.dart';

import '../core/actions/game_action.dart';
import '../game/tactical_game.dart';

class CombatHotbarOverlay extends StatelessWidget {
  final TacticalModeGame game;

  const CombatHotbarOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GamePhase>(
      valueListenable: game.phaseNotifier,
      builder: (context, phase, _) {
        final bottom =
            phase == GamePhase.planning || phase == GamePhase.executing
            ? 170.0
            : 20.0;
        return Positioned(
          left: 16,
          right: 16,
          bottom: bottom,
          child: ValueListenableBuilder<ActionType>(
            valueListenable: game.selectedActionNotifier,
            builder: (context, selected, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(10, (index) {
                  final action = TacticalModeGame.hotbarSlots[index];
                  final isSelected = action == selected;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      onTap: action == null
                          ? null
                          : () => game.selectHotbarSlot(index),
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF00E5FF).withValues(alpha: 0.25)
                              : const Color(0xFF10131E).withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF00E5FF)
                                : Colors.white24,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 3,
                              left: 5,
                              child: Text(
                                '${index == 9 ? 0 : index + 1}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Center(
                              child: Icon(
                                _iconFor(action),
                                color: action == null
                                    ? Colors.white12
                                    : Colors.white70,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        );
      },
    );
  }

  IconData _iconFor(ActionType? action) {
    switch (action) {
      case ActionType.slash:
        return Icons.sports_kabaddi;
      case ActionType.ranged:
        return Icons.arrow_forward;
      case ActionType.spell:
        return Icons.auto_awesome;
      case ActionType.dash:
        return Icons.fast_forward;
      case ActionType.heal:
        return Icons.favorite;
      default:
        return Icons.add;
    }
  }
}
