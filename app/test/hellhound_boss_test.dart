import 'package:flame/extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:builds_and_bosses_flame/game/components/arena_map_component.dart';
import 'package:builds_and_bosses_flame/game/components/hellhound_boss_component.dart';

import 'package:builds_and_bosses_flame/game/components/player_combat_controller.dart';
import 'package:builds_and_bosses_flame/game/components/player_component.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HellhoundBossComponent Patrol & Behavior Tests', () {
    late HellhoundBossComponent boss;
    const spawnX = 500.0;
    const spawnY = 300.0;

    setUp(() {
      boss = HellhoundBossComponent(
        position: Vector2(spawnX, spawnY),
        patrolDistance: 60.0,
        patrolSpeed: 40.0,
        strideLength: 40.0,
      );
      boss.isOnGround = true;
    });

    test(
      'Initializes with Hellhound stats, facing right, and rideable back',
      () {
        expect(boss.stats.name, equals('Hellhound'));
        expect(boss.stats.armorClass, equals(13));
        expect(boss.isRideable, isTrue);
        expect(boss.isFacingLeft, isFalse);
        expect(boss.patrolDirectionRight, isTrue);
        expect(boss.spawnOriginX, equals(spawnX));
        expect(boss.rideableBackSurface, isNotNull);
      },
    );

    test('Patrols left-to-right from spawn point up to patrolDistance', () {
      // Step 1 second -> moves right 40px
      boss.update(1.0);
      expect(boss.position.x, closeTo(spawnX + 40.0, 0.001));
      expect(boss.isFacingLeft, isFalse);
      expect(boss.patrolDirectionRight, isTrue);

      // Step another 0.6 second -> hits 60px bound, turns around
      boss.update(0.6);
      expect(boss.position.x, closeTo(spawnX + 60.0, 0.001));
      expect(boss.patrolDirectionRight, isFalse);
    });

    test(
      'Turns around and patrols right-to-left symmetrically to -patrolDistance',
      () {
        // Force to right boundary
        boss.position.x = spawnX + 60.0;
        boss.patrolDirectionRight = false;

        // Update 1.0s to the left
        boss.update(1.0);
        expect(boss.position.x, closeTo(spawnX + 20.0, 0.001));
        expect(boss.isFacingLeft, isTrue);

        // Update another 1.0s -> reaches spawnX - 20px
        boss.update(1.0);
        expect(boss.position.x, closeTo(spawnX - 20.0, 0.001));
        expect(boss.isFacingLeft, isTrue);

        // Update 1.0s -> reaches -60px bound (spawnX - 60px) and reverses to right
        boss.update(1.0);
        expect(boss.position.x, closeTo(spawnX - 60.0, 0.001));
        expect(boss.patrolDirectionRight, isTrue);
      },
    );

    test('Patrol halts when entity is dead', () {
      boss.stats.currentHp = 0;
      expect(boss.stats.isDead, isTrue);

      final prevX = boss.position.x;
      boss.update(1.0);
      expect(boss.position.x, equals(prevX));
      expect(boss.rideableBackSurface, isNull);
    });

    test('Patrol pauses during stagger/knockback force', () {
      boss.triggerStagger(50.0);
      expect(boss.staggerTimer, greaterThan(0.0));

      final prevX = boss.position.x;
      boss.update(0.1);
      expect(boss.position.x, equals(prevX));
    });

    test('Reverses direction at platform edge boundaries', () {
      final arena = ArenaMapComponent(arenaWidth: 960, arenaHeight: 540);
      boss.arena = arena;

      // Place on an arena platform
      final plat = arena.platforms.first;
      boss.position = Vector2(plat.right - 5, plat.top - boss.size.y / 2);
      boss.spawnOriginX = plat.center.dx;
      boss.patrolDirectionRight = true;

      // Updating should detect the platform edge and turn around to avoid walking off
      boss.update(0.1);
      expect(boss.patrolDirectionRight, isFalse);
    });

    test('Hellhound pushes player when walking into them at ground level', () {
      final player = PlayerComponent(
        position: Vector2(boss.position.x + 60, boss.position.y),
        movementBounds: const Rect.fromLTWH(0, 0, 1000, 500),
      );

      boss.resolvePlayerCollision(player: player);

      // Combined half width is (120 + 48) / 2 - 2 = 82
      final expectedX = boss.position.x + 82.0;
      expect(player.position.x, equals(expectedX));
    });

    test(
      'Hellhound turns around when player is pinned against right arena wall',
      () {
        final arena = ArenaMapComponent(arenaWidth: 600, arenaHeight: 400);
        final player = PlayerComponent(
          position: Vector2(580, boss.position.y),
          movementBounds: const Rect.fromLTWH(0, 0, 600, 400),
        );
        // Place boss close enough that pushing player exceeds wall
        boss.position.x = 520;
        boss.patrolDirectionRight = true;

        boss.resolvePlayerCollision(player: player, activeArena: arena);

        expect(boss.patrolDirectionRight, isFalse);
      },
    );

    test('Gaseous player is not pushed by Hellhound', () {
      final player = PlayerComponent(
        position: Vector2(boss.position.x + 60, boss.position.y),
        movementBounds: const Rect.fromLTWH(0, 0, 1000, 500),
      );
      player.isGaseous = true;

      final prevX = player.position.x;
      boss.resolvePlayerCollision(player: player);
      expect(player.position.x, equals(prevX));
    });

    test('Player walking towards Hellhound is body-blocked', () {
      final player = PlayerComponent(
        position: Vector2(boss.position.x - 70, boss.position.y),
        movementBounds: const Rect.fromLTWH(0, 0, 1000, 500),
      );
      final combat = PlayerCombatController();

      combat.resolveEnemyContactPush(
        playerPosition: player.position,
        playerSize: player.size,
        stats: player.stats,
        playerVelocityX: 1.0,
        dt: 0.016,
        enemies: [boss],
      );

      // Player should be clamped so they cannot penetrate into boss body
      final expectedX =
          boss.position.x - 80.0; // combined half width (48+120)/2 - 4 = 80
      expect(player.position.x, equals(expectedX));
    });
  });
}
