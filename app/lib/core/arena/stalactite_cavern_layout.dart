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
      ..._buildLeftSidePlatforms(),
      ..._buildCentralApproaches(),
      ..._buildRightSidePlatforms(),
    ];
  }

  static List<PlatformBlueprint> _buildLeftSidePlatforms() {
    return [
      // Left side - safe walking platform
      PlatformBlueprint(
        id: 'plat_lower_left_main',
        type: PlatformType.staticStone,
        x: 100.0,
        y: 1050.0,
        width: 350.0,
        height: 30.0,
      ),
      // Left side stalactite 1
      PlatformBlueprint(
        id: 'plat_stalactite_left_1',
        type: PlatformType.staticStone,
        x: 250.0,
        y: 200.0,
        width: 40.0,
        height: 150.0,
      ),
      // Left side stalactite 2
      PlatformBlueprint(
        id: 'plat_stalactite_left_2',
        type: PlatformType.staticStone,
        x: 450.0,
        y: 250.0,
        width: 40.0,
        height: 120.0,
      ),
      // Left side stalactite 3
      PlatformBlueprint(
        id: 'plat_stalactite_left_3',
        type: PlatformType.staticStone,
        x: 650.0,
        y: 300.0,
        width: 40.0,
        height: 100.0,
      ),
    ];
  }

  static List<PlatformBlueprint> _buildCentralApproaches() {
    return [
      // Center-left approach
      PlatformBlueprint(
        id: 'plat_lower_left_step',
        type: PlatformType.staticStone,
        x: 800.0,
        y: 950.0,
        width: 250.0,
        height: 25.0,
      ),
      // Center-right approach
      PlatformBlueprint(
        id: 'plat_lower_right_step',
        type: PlatformType.staticStone,
        x: 1950.0,
        y: 950.0,
        width: 250.0,
        height: 25.0,
      ),
    ];
  }

  static List<PlatformBlueprint> _buildRightSidePlatforms() {
    return [
      // Right side stalactite 1
      PlatformBlueprint(
        id: 'plat_stalactite_right_1',
        type: PlatformType.staticStone,
        x: 1860.0,
        y: 300.0,
        width: 40.0,
        height: 100.0,
      ),
      // Right side stalactite 2
      PlatformBlueprint(
        id: 'plat_stalactite_right_2',
        type: PlatformType.staticStone,
        x: 2060.0,
        y: 250.0,
        width: 40.0,
        height: 120.0,
      ),
      // Right side stalactite 3
      PlatformBlueprint(
        id: 'plat_stalactite_right_3',
        type: PlatformType.staticStone,
        x: 2260.0,
        y: 200.0,
        width: 40.0,
        height: 150.0,
      ),
      // Right side - safe walking platform
      PlatformBlueprint(
        id: 'plat_lower_right_main',
        type: PlatformType.staticStone,
        x: 2550.0,
        y: 1050.0,
        width: 350.0,
        height: 30.0,
      ),
    ];
  }

  static List<PlatformBlueprint> _buildCentralChasmPlatforms() {
    return [
      // Central pit left edge
      PlatformBlueprint(
        id: 'plat_chasm_pit_left',
        type: PlatformType.staticStone,
        x: 1300.0,
        y: 900.0,
        width: 120.0,
        height: 25.0,
      ),
      // Central pit right edge
      PlatformBlueprint(
        id: 'plat_chasm_pit_right',
        type: PlatformType.staticStone,
        x: 1580.0,
        y: 900.0,
        width: 120.0,
        height: 25.0,
      ),
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
      // Destructible ceiling center - main piece above chasm
      PlatformBlueprint(
        id: 'plat_ceiling_center',
        type: PlatformType.staticStone,
        x: 1300.0,
        y: 400.0,
        width: 400.0,
        height: 40.0,
      ),
      // Destructible ceiling left stalactite
      PlatformBlueprint(
        id: 'plat_ceiling_stalactite_left',
        type: PlatformType.staticStone,
        x: 1200.0,
        y: 500.0,
        width: 50.0,
        height: 120.0,
      ),
      // Destructible ceiling right stalactite
      PlatformBlueprint(
        id: 'plat_ceiling_stalactite_right',
        type: PlatformType.staticStone,
        x: 1550.0,
        y: 500.0,
        width: 50.0,
        height: 120.0,
      ),
    ];
  }

  static List<PlatformBlueprint> _buildUpperChamberPlatforms() {
    return [
      // Left eye of wolf (left triangle window)
      PlatformBlueprint(
        id: 'plat_upper_left_eye',
        type: PlatformType.staticStone,
        x: 1100.0,
        y: 200.0,
        width: 150.0,
        height: 20.0,
      ),
      // Right eye of wolf (right triangle window)
      PlatformBlueprint(
        id: 'plat_upper_right_eye',
        type: PlatformType.staticStone,
        x: 1550.0,
        y: 200.0,
        width: 150.0,
        height: 20.0,
      ),
      // Upper chamber center (nose/peak of wolf face)
      PlatformBlueprint(
        id: 'plat_upper_center_peak',
        type: PlatformType.staticStone,
        x: 1350.0,
        y: 100.0,
        width: 100.0,
        height: 15.0,
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
