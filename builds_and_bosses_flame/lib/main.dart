import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'game/tactical_game.dart';
import 'ui/action_bar_overlay.dart';
import 'ui/character_builder_overlay.dart';
import 'ui/planning_hud.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BuildsAndBossesApp());
}

class BuildsAndBossesApp extends StatelessWidget {
  const BuildsAndBossesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Builds & Bosses - Flame PoC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F111A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFFFFD54F),
          surface: Color(0xFF10131E),
        ),
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final TacticalModeGame _game;

  @override
  void initState() {
    super.initState();
    _game = TacticalModeGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Flame Game Canvas
          GameWidget<TacticalModeGame>(
            game: _game,
            overlayBuilderMap: {
              'planningHud': (context, game) => PlanningHUD(game: game),
              'actionBar': (context, game) => ActionBarOverlay(game: game),
              'characterBuilder': (context, game) => CharacterBuilderOverlay(game: game),
            },
            initialActiveOverlays: const ['planningHud'],
          ),

          // 2. Control Helper Tooltip in bottom corner
          Positioned(
            left: 16,
            bottom: 16,
            child: ValueListenableBuilder<GamePhase>(
              valueListenable: _game.phaseNotifier,
              builder: (context, phase, _) {
                if (phase == GamePhase.planning) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Text(
                    'Controls: A/D to run • SPACE / W to Jump (STR-scaled) • S to Drop • ENTER for Tactical Mode • B for Tervezőasztal',
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
