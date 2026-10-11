import '../dnd/character_stats.dart';

/// Bounding dimensions for Boss entities.
class BossDimensions {
  final double width;
  final double height;

  const BossDimensions({this.width = 120.0, this.height = 48.0});

  factory BossDimensions.fromJson(Map<String, dynamic> json) {
    return BossDimensions(
      width: (json['width'] as num?)?.toDouble() ?? 120.0,
      height: (json['height'] as num?)?.toDouble() ?? 48.0,
    );
  }

  Map<String, dynamic> toJson() => {'width': width, 'height': height};
}

/// Movement configuration for Boss entities.
class BossMovementConfig {
  final double patrolDistance;
  final double patrolSpeed;
  final double strideLength;

  const BossMovementConfig({
    this.patrolDistance = 75.0,
    this.patrolSpeed = 48.0,
    this.strideLength = 48.0,
  });

  factory BossMovementConfig.fromJson(Map<String, dynamic> json) {
    return BossMovementConfig(
      patrolDistance: (json['patrolDistance'] as num?)?.toDouble() ?? 75.0,
      patrolSpeed: (json['patrolSpeed'] as num?)?.toDouble() ?? 48.0,
      strideLength: (json['strideLength'] as num?)?.toDouble() ?? 48.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'patrolDistance': patrolDistance,
    'patrolSpeed': patrolSpeed,
    'strideLength': strideLength,
  };
}

/// Visual spritesheet metadata for Boss entities.
class BossVisualConfig {
  final String walkSheetPath;
  final double frameWidth;
  final double frameHeight;
  final int frameCount;

  const BossVisualConfig({
    required this.walkSheetPath,
    this.frameWidth = 160.0,
    this.frameHeight = 64.0,
    this.frameCount = 8,
  });

  factory BossVisualConfig.fromJson(Map<String, dynamic> json) {
    return BossVisualConfig(
      walkSheetPath: json['walkSheetPath'] as String? ?? '',
      frameWidth: (json['frameWidth'] as num?)?.toDouble() ?? 160.0,
      frameHeight: (json['frameHeight'] as num?)?.toDouble() ?? 64.0,
      frameCount: (json['frameCount'] as num?)?.toInt() ?? 8,
    );
  }

  Map<String, dynamic> toJson() => {
    'walkSheetPath': walkSheetPath,
    'frameWidth': frameWidth,
    'frameHeight': frameHeight,
    'frameCount': frameCount,
  };
}

/// Fully serializable data blueprint defining all behavioral, physical,
/// and visual parameters for a Boss in Builds & Bosses.
class BossBlueprint {
  final String id;
  final String name;
  final CharacterStats stats;
  final BossDimensions dimensions;
  final bool isRideable;
  final BossMovementConfig movement;
  final BossVisualConfig visuals;

  const BossBlueprint({
    required this.id,
    required this.name,
    required this.stats,
    this.dimensions = const BossDimensions(),
    this.isRideable = true,
    this.movement = const BossMovementConfig(),
    this.visuals = const BossVisualConfig(
      walkSheetPath: 'characters/hellhound/hellhound_walk_sheet.png',
    ),
  });

  double get width => dimensions.width;
  double get height => dimensions.height;

  /// Factory blueprint for the Twin-headed Hellhound boss.
  factory BossBlueprint.hellhound() {
    return BossBlueprint(
      id: 'boss_hellhound',
      name: 'Twin-headed Hellhound',
      stats: CharacterStats.hellhoundBoss(),
      dimensions: const BossDimensions(width: 120.0, height: 48.0),
      isRideable: true,
      movement: const BossMovementConfig(
        patrolDistance: 75.0,
        patrolSpeed: 48.0,
        strideLength: 48.0,
      ),
      visuals: const BossVisualConfig(
        walkSheetPath: 'characters/hellhound/hellhound_walk_sheet.png',
        frameWidth: 160.0,
        frameHeight: 64.0,
        frameCount: 8,
      ),
    );
  }

  BossBlueprint copyWith({
    CharacterStats? stats,
    BossDimensions? dimensions,
    BossMovementConfig? movement,
    BossVisualConfig? visuals,
  }) {
    return BossBlueprint(
      id: id,
      name: name,
      stats: stats ?? this.stats,
      dimensions: dimensions ?? this.dimensions,
      isRideable: isRideable,
      movement: movement ?? this.movement,
      visuals: visuals ?? this.visuals,
    );
  }

  factory BossBlueprint.fromJson(Map<String, dynamic> json) {
    return BossBlueprint(
      id: json['id'] as String? ?? 'boss_unknown',
      name: json['name'] as String? ?? 'Unknown Boss',
      stats: json['stats'] != null
          ? CharacterStats.fromJson(json['stats'] as Map<String, dynamic>)
          : CharacterStats.hellhoundBoss(),
      dimensions: json['dimensions'] != null
          ? BossDimensions.fromJson(json['dimensions'] as Map<String, dynamic>)
          : BossDimensions(
              width: (json['width'] as num?)?.toDouble() ?? 120.0,
              height: (json['height'] as num?)?.toDouble() ?? 48.0,
            ),
      isRideable: json['isRideable'] as bool? ?? true,
      movement: json['movement'] != null
          ? BossMovementConfig.fromJson(
              json['movement'] as Map<String, dynamic>,
            )
          : const BossMovementConfig(),
      visuals: json['visuals'] != null
          ? BossVisualConfig.fromJson(json['visuals'] as Map<String, dynamic>)
          : const BossVisualConfig(walkSheetPath: ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'stats': stats.toJson(),
    'dimensions': dimensions.toJson(),
    'isRideable': isRideable,
    'movement': movement.toJson(),
    'visuals': visuals.toJson(),
  };
}
