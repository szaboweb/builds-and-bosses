import 'package:builds_and_bosses_flame/core/arena/arena_layout_blueprint.dart';

/// Factory for creating the Stalactite Cavern level.
///
/// Layout Structure (2D Platformer - Side View):
/// - Left & right platforms for traversal
/// - CENTRAL PIT: huge empty space in the middle (falling hazard!)
/// - Hanging stalactites above the pit
/// - Bottom boundary (death zone below pit)
class StalactiteCavernLayout {
  static const double arenaWidth = 3000.0;
  static const double arenaHeight = 1200.0;
  static const double pitStartX = 900.0;
  static const double pitEndX = 2100.0;
  static const double pitTopY = 400.0;

  /// Creates the Stalactite Cavern level with central pit.
  static ArenaLayoutBlueprint stalactiteCavern() {
    return ArenaLayoutBlueprint(
      name: 'Stalactite Cavern',
      version: 1,
      arenaWidth: arenaWidth,
      arenaHeight: arenaHeight,
      playerSpawn: const SpawnPoint(300.0, 1050.0),
      platforms: _buildPlatforms(),
      spawns: _buildSpawns(),
    );
  }

  static List<PlatformBlueprint> _buildPlatforms() {
    return [
      ..._buildLeftSidePlatforms(),
      ..._buildRightSidePlatforms(),
      ..._buildStalactitesAbovePit(),
      ..._buildPitRim(),
      ..._buildBottomDeathZone(),
    ];
  }

  static List<PlatformBlueprint> _buildLeftSidePlatforms() {
    return [
      // Left main platform
      PlatformBlueprint(
        id: 'plat_left_main',
        type: PlatformType.staticStone,
        x: 100.0,
        y: 1050.0,
        width: 700.0,
        height: 40.0,
      ),
      // Left mid-level platform
      PlatformBlueprint(
        id: 'plat_left_mid',
        type: PlatformType.staticStone,
        x: 150.0,
        y: 650.0,
        width: 500.0,
        height: 40.0,
      ),
      // Left upper platform (approaching pit rim)
      PlatformBlueprint(
        id: 'plat_left_upper',
        type: PlatformType.staticStone,
        x: 200.0,
        y: 300.0,
        width: 400.0,
        height: 40.0,
      ),
    ];
  }

  static List<PlatformBlueprint> _buildRightSidePlatforms() {
    return [
      // Right main platform
      PlatformBlueprint(
        id: 'plat_right_main',
        type: PlatformType.staticStone,
        x: 2200.0,
        y: 1050.0,
        width: 700.0,
        height: 40.0,
      ),
      // Right mid-level platform
      PlatformBlueprint(
        id: 'plat_right_mid',
        type: PlatformType.staticStone,
        x: 2350.0,
        y: 650.0,
        width: 500.0,
        height: 40.0,
      ),
      // Right upper platform (approaching pit rim)
      PlatformBlueprint(
        id: 'plat_right_upper',
        type: PlatformType.staticStone,
        x: 2400.0,
        y: 300.0,
        width: 400.0,
        height: 40.0,
      ),
    ];
  }

  static List<PlatformBlueprint> _buildStalactitesAbovePit() {
    return [
      // Left side stalactites (3 hanging from ceiling)
      PlatformBlueprint(
        id: 'stala_left_1',
        type: PlatformType.staticStone,
        x: 1000.0,
        y: 50.0,
        width: 50.0,
        height: 280.0,
      ),
      PlatformBlueprint(
        id: 'stala_left_2',
        type: PlatformType.staticStone,
        x: 1100.0,
        y: 80.0,
        width: 45.0,
        height: 250.0,
      ),
      PlatformBlueprint(
        id: 'stala_left_3',
        type: PlatformType.staticStone,
        x: 1200.0,
        y: 100.0,
        width: 40.0,
        height: 230.0,
      ),
      // Right side stalactites (3 hanging from ceiling)
      PlatformBlueprint(
        id: 'stala_right_1',
        type: PlatformType.staticStone,
        x: 1800.0,
        y: 100.0,
        width: 40.0,
        height: 230.0,
      ),
      PlatformBlueprint(
        id: 'stala_right_2',
        type: PlatformType.staticStone,
        x: 1900.0,
        y: 80.0,
        width: 45.0,
        height: 250.0,
      ),
      PlatformBlueprint(
        id: 'stala_right_3',
        type: PlatformType.staticStone,
        x: 2000.0,
        y: 50.0,
        width: 50.0,
        height: 280.0,
      ),
    ];
  }

  static List<PlatformBlueprint> _buildPitRim() {
    return [
      // Left rim of pit
      PlatformBlueprint(
        id: 'pit_rim_left',
        type: PlatformType.staticStone,
        x: 850.0,
        y: pitTopY,
        width: 50.0,
        height: 40.0,
      ),
      // Right rim of pit
      PlatformBlueprint(
        id: 'pit_rim_right',
        type: PlatformType.staticStone,
        x: 2100.0,
        y: pitTopY,
        width: 50.0,
        height: 40.0,
      ),
    ];
  }

  static List<PlatformBlueprint> _buildBottomDeathZone() {
    return [
      // Bottom of cavern - outside pit (safe)
      PlatformBlueprint(
        id: 'bottom_left',
        type: PlatformType.staticStone,
        x: 0.0,
        y: 1150.0,
        width: 900.0,
        height: 50.0,
      ),
      PlatformBlueprint(
        id: 'bottom_right',
        type: PlatformType.staticStone,
        x: 2150.0,
        y: 1150.0,
        width: 850.0,
        height: 50.0,
      ),
    ];
  }

  static List<SpawnBlueprint> _buildSpawns() {
    return [
      // Enemy spawns on left safe platform
      SpawnBlueprint(
        id: 'enemy_left_1',
        type: 'stone_elemental',
        x: 400.0,
        y: 1000.0,
      ),
      SpawnBlueprint(
        id: 'enemy_left_2',
        type: 'stone_elemental',
        x: 600.0,
        y: 600.0,
      ),
      // Enemy spawns on right safe platform
      SpawnBlueprint(
        id: 'enemy_right_1',
        type: 'stone_elemental',
        x: 2600.0,
        y: 1000.0,
      ),
      SpawnBlueprint(
        id: 'enemy_right_2',
        type: 'stone_elemental',
        x: 2400.0,
        y: 600.0,
      ),
    ];
  }
}
