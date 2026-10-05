import 'package:flutter/material.dart';
import 'package:builds_and_bosses_flame/core/arena/arena_layout_blueprint.dart';
import 'package:builds_and_bosses_flame/core/arena/stalactite_cavern_layout.dart';

/// Overlay UI for selecting between available arena levels.
class LevelSelectorOverlay extends StatelessWidget {
  final Function(ArenaLayoutBlueprint) onLevelSelected;

  const LevelSelectorOverlay({super.key, required this.onLevelSelected});

  @override
  Widget build(BuildContext context) {
    final levels = <(String name, ArenaLayoutBlueprint blueprint)>[
      ('Cathedral of Trials (Default)', ArenaLayoutBlueprint.defaultArena()),
      ('Stalactite Cavern', StalactiteCavernLayout.stalactiteCavern()),
    ];

    return Center(
      child: Material(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Level',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ...levels.map((level) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ElevatedButton(
                    onPressed: () {
                      onLevelSelected(level.$2);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      minimumSize: const Size(300, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      level.$1,
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
