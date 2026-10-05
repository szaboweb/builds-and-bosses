import 'package:flutter/material.dart';

import '../../core/arena/arena_layout_blueprint.dart';
import '../../core/utils/unique_id.dart';
import '../../game/editor/arena_editor_controller.dart';
import 'palette_card_widget.dart';

/// Collapsible bottom drawer displaying palette cards for adding platforms
/// and entity spawn points to the level editor.
class LevelEditorDrawerWidget extends StatefulWidget {
  final ArenaEditorController controller;

  const LevelEditorDrawerWidget({super.key, required this.controller});

  @override
  State<LevelEditorDrawerWidget> createState() =>
      _LevelEditorDrawerWidgetState();
}

class _LevelEditorDrawerWidgetState extends State<LevelEditorDrawerWidget> {
  bool _isDrawerOpen = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDrawerHeader(),
        if (_isDrawerOpen) _buildDrawerCards(context),
      ],
    );
  }

  Widget _buildDrawerHeader() {
    return GestureDetector(
      key: const Key('editor_drawer_toggle'),
      onTap: () => setState(() => _isDrawerOpen = !_isDrawerOpen),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF10131E).withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          border: Border.all(color: const Color(0xFF263238), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isDrawerOpen
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_up,
              color: const Color(0xFFFFD54F),
              size: 16,
            ),
            const SizedBox(width: 4),
            const Text(
              'PALETTA',
              style: TextStyle(
                color: Color(0xFFFFD54F),
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerCards(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF10131E).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border.all(color: const Color(0xFF263238), width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ..._buildPlatformCards(),
            const SizedBox(width: 10),
            ..._buildSpawnCards(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPlatformCards() {
    return [
      PaletteCardWidget(
        key: const Key('palette_static_stone'),
        icon: Icons.crop_16_9,
        label: 'Kőplatform',
        subtitle: 'Statikus terep',
        accentColor: const Color(0xFFFFD54F),
        onTap: () {
          widget.controller.addPlatform(
            type: PlatformType.staticStone,
            x: 320.0,
            y: 400.0,
            width: 160.0,
            height: 20.0,
          );
        },
      ),
      const SizedBox(width: 10),
      PaletteCardWidget(
        key: const Key('palette_moving_stone'),
        icon: Icons.swap_horiz,
        label: 'Mozgó kő',
        subtitle: 'Kinematikus sín',
        accentColor: const Color(0xFFFF9100),
        onTap: () {
          widget.controller.addPlatform(
            type: PlatformType.movingStone,
            x: 320.0,
            y: 350.0,
            width: 160.0,
            height: 20.0,
            kinematics: const PlatformKinematics(
              travelDistance: 160.0,
              directionX: 1.0,
              speed: 90.0,
            ),
          );
        },
      ),
    ];
  }

  List<Widget> _buildSpawnCards() {
    return [
      PaletteCardWidget(
        key: const Key('palette_player_spawn'),
        icon: Icons.person_pin_circle,
        label: 'Játékos Spawn',
        subtitle: 'Kezdőpozíció',
        accentColor: const Color(0xFF00E5FF),
        onTap: () {
          widget.controller.blueprint.playerSpawn = const SpawnPoint(
            320.0,
            400.0,
          );
          widget.controller.notifyListeners();
        },
      ),
      const SizedBox(width: 10),
      PaletteCardWidget(
        key: const Key('palette_dummy_spawn'),
        icon: Icons.sports_kabaddi,
        label: 'Próbabábu',
        subtitle: 'Gyakorló ellenfél',
        accentColor: const Color(0xFFFF5252),
        onTap: () {
          widget.controller.blueprint.spawns.add(
            SpawnBlueprint(
              id: UniqueId.next('spawn'),
              type: 'training_dummy',
              x: 500.0,
              y: 400.0,
            ),
          );
          widget.controller.notifyListeners();
        },
      ),
    ];
  }
}
