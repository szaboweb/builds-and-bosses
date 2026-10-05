import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'platform/desktop_window.dart';
import 'game/tactical_game.dart';
import 'core/arena/arena_layout_blueprint.dart';
import 'ui/action_bar_overlay.dart';
import 'ui/character_builder_overlay.dart';
import 'ui/combat_log_overlay.dart';
import 'ui/combat_hotbar_overlay.dart';
import 'ui/combat_outcome_overlay.dart';
import 'ui/debug_info_overlay.dart';
import 'ui/planning_hud.dart';
import 'ui/level_selector_overlay.dart';
import 'core/inventory/equipment_grid.dart';
import 'ui/editor/level_editor_overlay.dart';
import 'ui/equipment_workshop_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Unhandled application error: $error');
    debugPrintStack(stackTrace: stack);
    return false;
  };
  await configureDesktopWindow().timeout(const Duration(seconds: 10));
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
  final EquipmentGrid _equipmentGrid = EquipmentGrid();
  int _equipmentRevision = 0;

  @override
  void initState() {
    super.initState();
    _game = TacticalModeGame();
  }

  @override
  void dispose() {
    _equipmentRevision++;
    _game.combatCompletion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildGameCanvas(),
          ..._buildTopActions(context),
          _buildControlsTooltip(),
        ],
      ),
    );
  }

  Widget _buildGameCanvas() {
    return GameWidget<TacticalModeGame>(
      game: _game,
      overlayBuilderMap: {
        'planningHud': (context, game) => PlanningHUD(game: game),
        'actionBar': (context, game) => ActionBarOverlay(game: game),
        'combatLog': (context, game) => CombatLogOverlay(game: game),
        'combatHotbar': (context, game) => CombatHotbarOverlay(game: game),
        'combatOutcome': (context, game) => CombatOutcomeOverlay(game: game),
        'debugInfo': (context, game) => DebugInfoOverlay(game: game),
        'characterBuilder': (context, game) =>
            CharacterBuilderOverlay(game: game),
        'levelEditor': (context, game) => LevelEditorOverlay(
          controller: game.editorController,
          onPlayTest: () => game.closeLevelEditor(),
          onClose: () => game.closeLevelEditor(),
        ),
        'levelSelector': (context, game) => LevelSelectorOverlay(
          onLevelSelected: (ArenaLayoutBlueprint blueprint) {
            game.loadLevel(blueprint);
          },
        ),
      },
      initialActiveOverlays: [
        'planningHud',
        'combatLog',
        'combatHotbar',
        if (kDebugMode) 'debugInfo',
      ],
    );
  }

  List<Widget> _buildTopActions(BuildContext context) {
    return [
      Positioned(
        top: 36,
        right: 16,
        child: IconButton.filledTonal(
          key: const Key('main_level_editor_button'),
          tooltip: 'Pályatervező Editor (F4)',
          onPressed: () => _game.toggleLevelEditor(),
          icon: const Icon(Icons.architecture),
        ),
      ),
      Positioned(
        top: 84,
        right: 16,
        child: IconButton.filledTonal(
          tooltip: 'Felszerelés workshop',
          onPressed: () => _openWorkshop(context),
          icon: const Icon(Icons.inventory_2_outlined),
        ),
      ),
      Positioned(
        top: 132,
        right: 16,
        child: ValueListenableBuilder<String?>(
          valueListenable: _game.combatCompletion.error,
          builder: (context, error, _) => error == null
              ? const SizedBox.shrink()
              : Tooltip(
                  message: error,
                  child: const Chip(
                    avatar: Icon(Icons.warning_amber),
                    label: Text('Mentési/platformhiba – lásd a naplót'),
                  ),
                ),
        ),
      ),
    ];
  }

  void _openWorkshop(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EquipmentWorkshopScreen(
          grid: _equipmentGrid,
          onEquipmentChanged: (items) async {
            final revision = ++_equipmentRevision;
            await _game.ready();
            if (revision != _equipmentRevision) {
              throw StateError('Equipment operation cancelled.');
            }
            await _game.player.setEquipment(items);
          },
          onCancelEquipmentUpdate: () {
            _equipmentRevision++;
            if (_game.isLoaded) {
              _game.player.cancelEquipmentUpdate();
            }
          },
        ),
      ),
    );
  }

  Widget _buildControlsTooltip() {
    return Positioned(
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
              'Controls: A/D run • W/S fly • SPACE jump • E melee • R ranged • C spell • TAB mode • F4 editor • B builder',
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
          );
        },
      ),
    );
  }
}
