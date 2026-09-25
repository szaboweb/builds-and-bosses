import 'package:flutter/material.dart';

import '../game/tactical_game.dart';

class CombatOutcomeOverlay extends StatelessWidget {
  final TacticalModeGame game;

  const CombatOutcomeOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ValueListenableBuilder<CombatOutcome?>(
        valueListenable: game.combatOutcomeNotifier,
        builder: (context, outcome, _) {
          if (outcome == null) return const SizedBox.shrink();
          final victory = outcome == CombatOutcome.victory;
          return Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF10131E).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: victory ? const Color(0xFFFFD54F) : Colors.redAccent,
                  width: 2,
                ),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    victory ? Icons.emoji_events : Icons.dangerous,
                    color: victory ? const Color(0xFFFFD54F) : Colors.redAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    victory ? 'VICTORY' : 'DEFEAT',
                    style: TextStyle(
                      color: victory ? const Color(0xFFFFD54F) : Colors.redAccent,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: game.restartCombat,
                    icon: const Icon(Icons.replay),
                    label: const Text('RESTART COMBAT'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}