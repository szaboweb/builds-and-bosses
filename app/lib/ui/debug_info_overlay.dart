import 'package:flutter/material.dart';

import '../game/tactical_game.dart';

class DebugInfoOverlay extends StatelessWidget {
  final TacticalModeGame game;

  const DebugInfoOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: game.debugTickNotifier,
      builder: (context, tick, _) {
        if (!game.debugHudEnabled) return const SizedBox.shrink();
        final playerPosition = game.player.position;
        final cameraPosition = game.camera.viewfinder.position;
        final distance = playerPosition.distanceTo(game.enemy.position);
        final mode = game.selectedActionNotifier.value.name.toUpperCase();
        return Positioned(
          top: 88,
          left: 16,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                border: Border.all(
                  color: Colors.greenAccent.withValues(alpha: 0.7),
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'DEBUG [F3]\n'
                  'phase: ${game.currentPhase.name}\n'
                  'mode: $mode\n'
                  'player: (${playerPosition.x.toStringAsFixed(0)}, ${playerPosition.y.toStringAsFixed(0)})\n'
                  'camera: (${cameraPosition.x.toStringAsFixed(0)}, ${cameraPosition.y.toStringAsFixed(0)})\n'
                  'target distance: ${distance.toStringAsFixed(0)}\n'
                  'action cd: ${game.actionCooldowns.remainingForAbility(game.selectedActionNotifier.value).toStringAsFixed(2)}s',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
