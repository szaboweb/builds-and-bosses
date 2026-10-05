import 'package:builds_and_bosses_flame/core/arena/arena_layout_blueprint.dart';

/// Factory for creating the Stalactite Cavern level.
///
/// Layout Structure (2D Platformer):
/// - Wide rectangular chamber with platforms on left/right
/// - Central chasm pit (falling hazard)
/// - Destructible ceiling that reveals upper chamber
/// - Upper chamber accessible only with climbing/flying
class StalactiteCavernLayout {
  /// Creates the Stalactite Cavern level (platformer variant).
  static ArenaLayoutBlueprint stalactiteCavern() {
    return ArenaLayoutBlueprint(
      name: 'Stalactite Cavern',
      version: 1,
      arenaWidth: 3000.0,
      arenaHeight: 1200.0,
      playerSpawn: const SpawnPoint(200.0, 1050.0),
      platforms: _buildPlatforms(),
      spawns: _buildSpawns(),
    );
  }

  static List<PlatformBlueprint> _buildPlatforms() {
    return [
      ..._buildLowerLevelPlatforms(),
      ..._buildCentralChasmPlatforms(),
      ..._buildDestructibleCeiling(),
      ..._buildUpperChamberPlatforms(),
      ..._buildTraversalElements(),
    ];
  }

  static List<PlatformBlueprint> _buildLowerLevelPlatforms() {
    return [
      // Left side - safe walking platform
      PlatformBlueprint(
        id: 'plat_lower_left_main',
        type: PlatformType.staticStone,
        x: 100.0,
        y: 1050.0,
        width: 400.0,
        height: 30.0,
      ),
      // Center-left approach
      PlatformBlueprint(
        id: 'plat_lower_left_step',
        type: PlatformType.staticStone,
        x: 500.0,
        y: 950.0,
        width: 250.0,
        height: 25.0,
      ),
      // Center-right approach
      PlatformBlueprint(
        id: 'plat_lower_right_step',
        type: PlatformType.staticStone,
        x: 2250.0,
        y: 950.0,
        width: 250.0,
        height: 25.0,
      ),
      // Right side - safe walking platform
      PlatformBlueprint(
        id: 'plat_lower_right_main',
        type: PlatformType.staticStone,
        x: 2500.0,
        y: 1050.0,
        width: 400.0,
        height: 30.0,
      ),
    ];
  }

  static List<PlatformBlueprint> _buildCentralChasmPlatforms() {
    return [
      // Chasm floor (deep bottom, lethal fall)
      PlatformBlueprint(
        id: 'plat_chasm_floor',
        type: PlatformType.staticStone,
        x: 1000.0,
        y: 1100.0,
        width: 1000.0,
        height: 20.0,
      ),
    ];
  }

  static List<PlatformBlueprint> _buildDestructibleCeiling() {
    return [
      // Main ceiling platform (destructible, collapses to open passage)
      PlatformBlueprint(
        id: 'plat_ceiling_section',
        type: PlatformType.staticStone,
        x: 1200.0,
        y: 400.0,
        width: 600.0,
        height: 30.0,
      ),
    ];
  }

  static List<PlatformBlueprint> _buildUpperChamberPlatforms() {
    return [
      // Upper left platform (wolf's eye chamber)
      PlatformBlueprint(
        id: 'plat_upper_left',
        type: PlatformType.staticStone,
        x: 1000.0,
        y: 300.0,
        width: 300.0,
        height: 25.0,
      ),
      // Upper center platform (peak of wolf's eye)
      PlatformBlueprint(
        id: 'plat_upper_center',
        type: PlatformType.staticStone,
        x: 1350.0,
        y: 150.0,
        width: 300.0,
        height: 20.0,
      ),
      // Upper right platform (wolf's eye chamber)
      PlatformBlueprint(
        id: 'plat_upper_right',
        type: PlatformType.staticStone,
        x: 1700.0,
        y: 300.0,
        width: 300.0,
        height: 25.0,
      ),
    ];
  }

  static List<PlatformBlueprint> _buildTraversalElements() {
    return [
      // Left staircase
      PlatformBlueprint(
        id: 'plat_stairs_left_1',
        type: PlatformType.staticStone,
        x: 400.0,
        y: 1000.0,
        width: 80.0,
        height: 20.0,
      ),
      PlatformBlueprint(
        id: 'plat_stairs_left_2',
        type: PlatformType.staticStone,
        x: 350.0,
        y: 950.0,
        width: 80.0,
        height: 20.0,
      ),
      // Right staircase
      PlatformBlueprint(
        id: 'plat_stairs_right_1',
        type: PlatformType.staticStone,
        x: 2520.0,
        y: 1000.0,
        width: 80.0,
        height: 20.0,
      ),
      PlatformBlueprint(
        id: 'plat_stairs_right_2',
        type: PlatformType.staticStone,
        x: 2570.0,
        y: 950.0,
        width: 80.0,
        height: 20.0,
      ),
    ];
  }

  static List<SpawnBlueprint> _buildSpawns() {
    return [
      // Stone Elemental enemies
      SpawnBlueprint(
        id: 'enemy_stone_elemental_1',
        type: 'stone_elemental',
        x: 800.0,
        y: 920.0,
      ),
      SpawnBlueprint(
        id: 'enemy_stone_elemental_2',
        type: 'stone_elemental',
        x: 2200.0,
        y: 920.0,
      ),
      // Stalactite Bats (aerial threats)
      SpawnBlueprint(
        id: 'enemy_bat_swarm_1',
        type: 'stalactite_bat_swarm',
        x: 600.0,
        y: 700.0,
      ),
      SpawnBlueprint(
        id: 'enemy_bat_swarm_2',
        type: 'stalactite_bat_swarm',
        x: 2400.0,
        y: 700.0,
      ),
      // Boss encounter
      SpawnBlueprint(
        id: 'boss_wolf_kin',
        type: 'wolf_kin_shaman',
        x: 1500.0,
        y: 150.0,
      ),
    ];
  }
}
