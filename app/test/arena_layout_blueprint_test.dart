import 'package:flutter_test/flutter_test.dart';
import 'package:builds_and_bosses_flame/core/arena/arena_layout_blueprint.dart';

void main() {
  group('PlatformBlueprint', () {
    test('Static platform serializes and deserializes correctly', () {
      final staticPlat = PlatformBlueprint(
        id: 'plat_01',
        type: PlatformType.staticStone,
        x: 100.0,
        y: 700.0,
        width: 200.0,
        height: 25.0,
      );

      expect(staticPlat.isMoving, isFalse);
      expect(staticPlat.endX, equals(100.0));
      expect(staticPlat.endY, equals(700.0));

      final json = staticPlat.toJson();
      final restored = PlatformBlueprint.fromJson(json);

      expect(restored.id, equals('plat_01'));
      expect(restored.type, equals(PlatformType.staticStone));
      expect(restored.x, equals(100.0));
      expect(restored.y, equals(700.0));
      expect(restored.width, equals(200.0));
      expect(restored.height, equals(25.0));
      expect(restored.isMoving, isFalse);
    });

    test('Moving platform calculates turn-around endpoints and serializes kinematics', () {
      final movingPlat = PlatformBlueprint(
        id: 'plat_mov_01',
        type: PlatformType.movingStone,
        x: 400.0,
        y: 600.0,
        width: 150.0,
        height: 20.0,
        kinematics: const PlatformKinematics(
          directionX: 1.0,
          directionY: 0.0,
          travelDistance: 350.0,
          speed: 120.0,
        ),
      );

      expect(movingPlat.isMoving, isTrue);
      expect(movingPlat.endX, equals(750.0));
      expect(movingPlat.endY, equals(600.0));

      final json = movingPlat.toJson();
      final restored = PlatformBlueprint.fromJson(json);

      expect(restored.id, equals('plat_mov_01'));
      expect(restored.type, equals(PlatformType.movingStone));
      expect(restored.travelDistance, equals(350.0));
      expect(restored.directionX, equals(1.0));
      expect(restored.directionY, equals(0.0));
      expect(restored.speed, equals(120.0));
      expect(restored.endX, equals(750.0));
    });
  });

  group('SpawnBlueprint', () {
    test('Serializes entity spawn points', () {
      final spawn = SpawnBlueprint(
        id: 'dummy_01',
        type: 'training_dummy',
        x: 1800.0,
        y: 720.0,
      );

      final json = spawn.toJson();
      final restored = SpawnBlueprint.fromJson(json);

      expect(restored.id, equals('dummy_01'));
      expect(restored.type, equals('training_dummy'));
      expect(restored.x, equals(1800.0));
      expect(restored.y, equals(720.0));
    });
  });

  group('ArenaLayoutBlueprint', () {
    test('Default arena factory builds complete arena layout', () {
      final layout = ArenaLayoutBlueprint.defaultArena();

      expect(layout.name, equals('Cathedral of Trials'));
      expect(layout.arenaWidth, equals(2400.0));
      expect(layout.arenaHeight, equals(900.0));
      expect(layout.playerSpawnX, equals(180.0));
      expect(layout.platforms.length, equals(5));
      expect(layout.platforms.any((p) => p.isMoving), isTrue);
      expect(layout.spawns.length, equals(1));
      expect(layout.isValid(), isTrue);
    });

    test('Validation checks boundary constraints and positive sizes', () {
      final valid = ArenaLayoutBlueprint.defaultArena();
      expect(valid.isValid(), isTrue);

      final invalidWidth = ArenaLayoutBlueprint(
        arenaWidth: -100,
        arenaHeight: 900,
      );
      expect(invalidWidth.isValid(), isFalse);

      final invalidSpawn = ArenaLayoutBlueprint(
        arenaWidth: 2400,
        arenaHeight: 900,
        playerSpawn: const SpawnPoint(3000, 822), // outside arena width
      );
      expect(invalidSpawn.isValid(), isFalse);

      final invalidPlatformSize = ArenaLayoutBlueprint(
        platforms: [
          PlatformBlueprint(
            id: 'bad_plat',
            type: PlatformType.staticStone,
            x: 100,
            y: 100,
            width: -50,
            height: 20,
          ),
        ],
      );
      expect(invalidPlatformSize.isValid(), isFalse);
    });

    test('Complete JSON round-trip serialization and deserialization', () {
      final original = ArenaLayoutBlueprint.defaultArena();

      final jsonString = original.toJsonString(pretty: true);
      expect(jsonString, contains('"name": "Cathedral of Trials"'));
      expect(jsonString, contains('"type": "movingStone"'));

      final restored = ArenaLayoutBlueprint.fromJsonString(jsonString);

      expect(restored.name, equals(original.name));
      expect(restored.version, equals(original.version));
      expect(restored.arenaWidth, equals(original.arenaWidth));
      expect(restored.arenaHeight, equals(original.arenaHeight));
      expect(restored.playerSpawnX, equals(original.playerSpawnX));
      expect(restored.playerSpawnY, equals(original.playerSpawnY));
      expect(restored.platforms.length, equals(original.platforms.length));
      expect(restored.spawns.length, equals(original.spawns.length));

      // Inspect moving platform restoration
      final restoredMoving = restored.platforms.firstWhere((p) => p.isMoving);
      expect(restoredMoving.travelDistance, equals(500.0));
      expect(restoredMoving.speed, equals(90.0));
      expect(restoredMoving.directionX, equals(1.0));
    });
  });
}
