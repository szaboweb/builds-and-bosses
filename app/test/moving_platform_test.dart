import 'package:flutter_test/flutter_test.dart';
import 'package:flame/extensions.dart';
import 'package:builds_and_bosses_flame/core/dnd/character_stats.dart';
import 'package:builds_and_bosses_flame/game/components/arena_map_component.dart';
import 'package:builds_and_bosses_flame/game/components/moving_platform_component.dart';
import 'package:builds_and_bosses_flame/game/components/player_locomotion_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MovingPlatformComponent Physics & Kinematics', () {
    test('Oscillates horizontally and updates lastDisplacementX', () {
      final platform = MovingPlatformComponent(
        initialPosition: Vector2(400, 625),
        size: Vector2(160, 20),
        minX: 400,
        maxX: 600,
        speed: 100,
      );

      expect(platform.direction, equals(1.0));
      expect(platform.lastDisplacementX, equals(0.0));

      // Update 0.5s -> moves +50px
      platform.update(0.5);
      expect(platform.position.x, equals(450.0));
      expect(platform.lastDisplacementX, closeTo(50.0, 0.01));
      expect(platform.direction, equals(1.0));

      // Update 2.0s -> reaches maxX (600) and turns around
      platform.update(2.0);
      expect(platform.position.x, equals(600.0));
      expect(platform.direction, equals(-1.0));

      // Update 0.5s -> moves left (-50px)
      platform.update(0.5);
      expect(platform.position.x, equals(550.0));
      expect(platform.lastDisplacementX, closeTo(-50.0, 0.01));
      expect(platform.direction, equals(-1.0));
    });

    test('Strength gating: requires at least 18 STR to land on platform', () {
      final platform = MovingPlatformComponent(
        initialPosition: Vector2(400, 625),
        size: Vector2(160, 20),
        minX: 400,
        maxX: 600,
        requiredStrength: 18,
      );

      expect(platform.canSupportCharacter(8), isFalse);
      expect(platform.canSupportCharacter(10), isFalse);
      expect(platform.canSupportCharacter(16), isFalse);
      expect(platform.canSupportCharacter(17), isFalse);
      expect(platform.canSupportCharacter(18), isTrue);
      expect(platform.canSupportCharacter(20), isTrue);
    });
  });

  group('D&D 2024 Vertical Jump Physics & Clearance Gating', () {
    test('Calculated jump apex height for STR 16 vs STR 18 vs STR 20', () {
      final str16 = CharacterStats.fighterProtagonist().copyWith(strength: 16);
      final str18 = CharacterStats.fighterProtagonist().copyWith(strength: 18);
      final str20 = CharacterStats.fighterProtagonist().copyWith(strength: 20);

      // Height difference between first platform and moving platform is 120px
      const platformHeightDifference = 120.0;

      // STR 16: max jump height ~115.6px (< 120px -> cannot reach)
      expect(str16.maxJumpHeight, closeTo(115.6, 0.1));
      expect(str16.maxJumpHeight < platformHeightDifference, isTrue);

      // STR 18: max jump height ~126.5px (> 120px -> clears platform height)
      expect(str18.maxJumpHeight, closeTo(126.5, 0.1));
      expect(str18.maxJumpHeight > platformHeightDifference, isTrue);

      // STR 20: max jump height ~138.0px (> 120px -> easily reaches platform)
      expect(str20.maxJumpHeight, closeTo(138.0, 0.1));
      expect(str20.maxJumpHeight > platformHeightDifference, isTrue);
    });
  });

  group('ArenaMapComponent Moving Platform Integration', () {
    test('Arena creates moving platform between first and center platform', () {
      final arena = ArenaMapComponent(arenaWidth: 2400, arenaHeight: 900);

      expect(arena.movingPlatform, isNotNull);
      expect(arena.platforms, contains(arena.movingPlatform.toRect()));

      // First platform right edge is 300
      final firstPlat = arena.staticPlatforms.first;
      expect(firstPlat.right, equals(300.0));
      expect(firstPlat.top, equals(900 - 155.0)); // 745

      // Moving platform elevation is 120px above first platform
      expect(arena.movingPlatform.position.y, equals(900 - 275.0)); // 625
      expect(firstPlat.top - arena.movingPlatform.position.y, equals(120.0));

      // Center throne platform left edge is 1070
      final centerPlat = arena.staticPlatforms[2];
      expect(centerPlat.left, equals(1070.0));
      expect(
        centerPlat.top,
        equals(900 - 265.0),
      ); // 635 (10px below moving platform)

      // Moving platform travels between first platform and center platform
      expect(arena.movingPlatform.minX, greaterThanOrEqualTo(firstPlat.right));
      expect(
        arena.movingPlatform.maxX + arena.movingPlatform.size.x,
        lessThanOrEqualTo(centerPlat.left),
      );
    });

    test('getSurfaceYBelow detects moving platform surface', () {
      final arena = ArenaMapComponent(arenaWidth: 2400, arenaHeight: 900);
      arena.movingPlatform.position.x = 500;

      // Surface directly above moving platform
      final surfaceY = arena.getSurfaceYBelow(Vector2(550, 600));
      expect(surfaceY, equals(arena.movingPlatform.position.y));
    });
  });

  group('PlayerLocomotionController Riding & Strength Collision', () {
    late ArenaMapComponent arena;
    late PlayerLocomotionController locomotion;

    setUp(() {
      arena = ArenaMapComponent(arenaWidth: 2400, arenaHeight: 900);
      arena.movingPlatform.position.x = 500;
      locomotion = PlayerLocomotionController();
    });

    test('Character with STR 16 cannot land on moving platform', () {
      final playerPos = Vector2(550, 625 - 26);
      final playerSize = Vector2(32, 52);

      locomotion.characterStrength = 16;
      locomotion.updatePhysics(
        dt: 0.016,
        position: playerPos,
        size: playerSize,
        moveSpeed: 180,
        gravity: 980,
        movementBounds: arena.playableBounds,
        arena: arena,
      );

      expect(locomotion.isOnMovingPlatform, isFalse);
    });

    test('Character with STR 18 lands and is carried by moving platform', () {
      final playerPos = Vector2(550, 625 - 26);
      final playerSize = Vector2(32, 52);

      // 1. Initial landing with STR 18
      locomotion.characterStrength = 18;
      locomotion.updatePhysics(
        dt: 0.016,
        position: playerPos,
        size: playerSize,
        moveSpeed: 180,
        gravity: 980,
        movementBounds: arena.playableBounds,
        arena: arena,
      );

      expect(locomotion.isOnGround, isTrue);
      expect(locomotion.isOnMovingPlatform, isTrue);
      expect(playerPos.y, equals(625 - 26));

      // 2. Next frame: platform moves horizontally
      arena.movingPlatform.lastDisplacementX = 2.5;
      final initialX = playerPos.x;

      locomotion.updatePhysics(
        dt: 0.016,
        position: playerPos,
        size: playerSize,
        moveSpeed: 180,
        gravity: 980,
        movementBounds: arena.playableBounds,
        arena: arena,
      );

      // Player was carried by 2.5px along with the platform
      expect(playerPos.x, closeTo(initialX + 2.5, 0.01));
      expect(locomotion.isOnMovingPlatform, isTrue);
    });

    test('Jumping leaves the moving platform', () {
      final playerPos = Vector2(550, 625 - 26);
      final playerSize = Vector2(32, 52);

      locomotion.characterStrength = 18;
      locomotion.updatePhysics(
        dt: 0.016,
        position: playerPos,
        size: playerSize,
        moveSpeed: 180,
        gravity: 980,
        movementBounds: arena.playableBounds,
        arena: arena,
      );

      expect(locomotion.isOnMovingPlatform, isTrue);

      final jumped = locomotion.jump(jumpVelocity: -498.0);
      expect(jumped, isTrue);
      expect(locomotion.isOnGround, isFalse);
      expect(locomotion.isOnMovingPlatform, isFalse);
    });
  });
}
