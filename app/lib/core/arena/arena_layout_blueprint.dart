import 'dart:convert';

/// Discriminates between stationary and kinematic stone platforms.
enum PlatformType { staticStone, movingStone }

/// Kinematic trajectory configuration for a moving platform.
class PlatformKinematics {
  final double travelDistance;
  final double directionX;
  final double directionY;
  final double speed;

  const PlatformKinematics({
    this.travelDistance = 0.0,
    this.directionX = 1.0,
    this.directionY = 0.0,
    this.speed = 90.0,
  });

  Map<String, dynamic> toJson() => {
    'travelDistance': travelDistance,
    'directionX': directionX,
    'directionY': directionY,
    'speed': speed,
  };

  factory PlatformKinematics.fromJson(Map<String, dynamic> json) {
    return PlatformKinematics(
      travelDistance: (json['travelDistance'] as num?)?.toDouble() ?? 0.0,
      directionX: (json['directionX'] as num?)?.toDouble() ?? 1.0,
      directionY: (json['directionY'] as num?)?.toDouble() ?? 0.0,
      speed: (json['speed'] as num?)?.toDouble() ?? 90.0,
    );
  }
}

/// Blueprint definition of an individual stone platform in the arena.
class PlatformBlueprint {
  final String id;
  PlatformType type;
  double x;
  double y;
  double width;
  double height;
  PlatformKinematics? kinematics;

  PlatformBlueprint({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.kinematics,
  });

  bool get isMoving => type == PlatformType.movingStone;

  double get travelDistance => kinematics?.travelDistance ?? 0.0;
  double get directionX => kinematics?.directionX ?? 1.0;
  double get directionY => kinematics?.directionY ?? 0.0;
  double get speed => kinematics?.speed ?? 90.0;

  /// Theoretical turn-around point of the moving platform.
  double get endX => x + (directionX * travelDistance);
  double get endY => y + (directionY * travelDistance);

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    if (kinematics != null) ...kinematics!.toJson(),
  };

  factory PlatformBlueprint.fromJson(Map<String, dynamic> json) {
    final type = PlatformType.values.byName(json['type'] as String);
    return PlatformBlueprint(
      id: json['id'] as String,
      type: type,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      kinematics: type == PlatformType.movingStone
          ? PlatformKinematics.fromJson(json)
          : null,
    );
  }
}

/// Blueprint definition of an entity spawn point (player, dummy, boss).
class SpawnBlueprint {
  final String id;
  final String type;
  double x;
  double y;

  SpawnBlueprint({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
  });

  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'x': x, 'y': y};

  factory SpawnBlueprint.fromJson(Map<String, dynamic> json) {
    return SpawnBlueprint(
      id: json['id'] as String,
      type: json['type'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }
}

/// 2D coordinate pair for spawn positions.
class SpawnPoint {
  final double x;
  final double y;

  const SpawnPoint(this.x, this.y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory SpawnPoint.fromJson(Map<String, dynamic> json) {
    return SpawnPoint(
      (json['x'] as num).toDouble(),
      (json['y'] as num).toDouble(),
    );
  }
}

/// Headless layout specification for an entire arena level.
///
/// Can be serialized to/from JSON for persistence in PlatformServices,
/// level editor loading/saving, and dynamic Flame scene construction.
class ArenaLayoutBlueprint {
  final String name;
  final int version;
  final double arenaWidth;
  final double arenaHeight;
  SpawnPoint playerSpawn;
  final List<PlatformBlueprint> platforms;
  final List<SpawnBlueprint> spawns;

  ArenaLayoutBlueprint({
    this.name = 'Custom Dungeon Arena',
    this.version = 1,
    this.arenaWidth = 2400.0,
    this.arenaHeight = 900.0,
    this.playerSpawn = const SpawnPoint(180.0, 822.0),
    List<PlatformBlueprint>? platforms,
    List<SpawnBlueprint>? spawns,
  }) : platforms = platforms ?? [],
       spawns = spawns ?? [];

  double get playerSpawnX => playerSpawn.x;
  double get playerSpawnY => playerSpawn.y;

  /// Factory creating the standard gothic dungeon layout matching the current game.
  factory ArenaLayoutBlueprint.defaultArena() {
    return ArenaLayoutBlueprint(
      name: 'Cathedral of Trials',
      version: 1,
      arenaWidth: 2400.0,
      arenaHeight: 900.0,
      playerSpawn: const SpawnPoint(180.0, 822.0),
      platforms: [
        PlatformBlueprint(
          id: 'plat_lower_left',
          type: PlatformType.staticStone,
          x: 100.0,
          y: 745.0,
          width: 200.0,
          height: 20.0,
        ),
        PlatformBlueprint(
          id: 'plat_lower_right',
          type: PlatformType.staticStone,
          x: 2100.0,
          y: 745.0,
          width: 200.0,
          height: 20.0,
        ),
        PlatformBlueprint(
          id: 'plat_center_throne',
          type: PlatformType.staticStone,
          x: 1070.0,
          y: 635.0,
          width: 260.0,
          height: 22.0,
        ),
        PlatformBlueprint(
          id: 'plat_upper_bridge',
          type: PlatformType.staticStone,
          x: 1130.0,
          y: 525.0,
          width: 140.0,
          height: 18.0,
        ),
        PlatformBlueprint(
          id: 'plat_moving_trials',
          type: PlatformType.movingStone,
          x: 390.0,
          y: 625.0,
          width: 160.0,
          height: 20.0,
          kinematics: const PlatformKinematics(
            directionX: 1.0,
            directionY: 0.0,
            travelDistance: 500.0,
            speed: 90.0,
          ),
        ),
      ],
      spawns: [
        SpawnBlueprint(
          id: 'spawn_dummy_vanguard',
          type: 'training_dummy',
          x: 2200.0,
          y: 719.0,
        ),
      ],
    );
  }

  /// Validates consistency: dimensions positive, spawns inside arena boundaries.
  bool isValid() {
    if (arenaWidth <= 0 || arenaHeight <= 0) return false;
    if (playerSpawnX < 0 || playerSpawnX > arenaWidth) return false;
    if (playerSpawnY < 0 || playerSpawnY > arenaHeight) return false;
    for (final p in platforms) {
      if (p.width <= 0 || p.height <= 0) return false;
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'version': version,
    'arenaWidth': arenaWidth,
    'arenaHeight': arenaHeight,
    'playerSpawnX': playerSpawnX,
    'playerSpawnY': playerSpawnY,
    'platforms': platforms.map((p) => p.toJson()).toList(),
    'spawns': spawns.map((s) => s.toJson()).toList(),
  };

  String toJsonString({bool pretty = false}) {
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(toJson());
    }
    return jsonEncode(toJson());
  }

  factory ArenaLayoutBlueprint.fromJson(Map<String, dynamic> json) {
    return ArenaLayoutBlueprint(
      name: json['name'] as String? ?? 'Custom Dungeon Arena',
      version: json['version'] as int? ?? 1,
      arenaWidth: (json['arenaWidth'] as num?)?.toDouble() ?? 2400.0,
      arenaHeight: (json['arenaHeight'] as num?)?.toDouble() ?? 900.0,
      playerSpawn: SpawnPoint(
        (json['playerSpawnX'] as num?)?.toDouble() ?? 180.0,
        (json['playerSpawnY'] as num?)?.toDouble() ?? 822.0,
      ),
      platforms:
          (json['platforms'] as List<dynamic>?)
              ?.map(
                (e) => PlatformBlueprint.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      spawns:
          (json['spawns'] as List<dynamic>?)
              ?.map((e) => SpawnBlueprint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  factory ArenaLayoutBlueprint.fromJsonString(String source) {
    return ArenaLayoutBlueprint.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );
  }
}
