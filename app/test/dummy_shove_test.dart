import 'package:flutter_test/flutter_test.dart';
import 'package:flame/extensions.dart';
import 'package:builds_and_bosses_flame/core/dnd/character_stats.dart';
import 'package:builds_and_bosses_flame/game/components/arena_map_component.dart';
import 'package:builds_and_bosses_flame/game/components/dummy_enemy_component.dart';
import 'package:builds_and_bosses_flame/game/components/player_combat_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('D&D Strength Shove & Knockback Core Rules', () {
    test(
      'Standard and low Strength characters cannot shove heavy combat dummy',
      () {
        final weakFighter = CharacterStats.fighterProtagonist().copyWith(
          strength: 8,
        );
        final standardFighter = CharacterStats.fighterProtagonist().copyWith(
          strength: 10,
        );

        expect(weakFighter.strengthMod, equals(-1));
        expect(weakFighter.meleeKnockback, equals(0.0));
        expect(weakFighter.canShoveOnContact, isFalse);

        expect(standardFighter.strengthMod, equals(0));
        expect(standardFighter.meleeKnockback, equals(0.0));
        expect(standardFighter.canShoveOnContact, isFalse);
      },
    );

    test('Above-average and high Strength scales melee knockback and contact shove', () {
      final athleticFighter = CharacterStats.fighterProtagonist().copyWith(
        strength: 14,
      );
      final strongFighter = CharacterStats.fighterProtagonist().copyWith(
        strength: 16,
      );
      final apexFighter = CharacterStats.fighterProtagonist().copyWith(
        strength: 20,
      );

      expect(athleticFighter.meleeKnockback, equals(128.0));
      expect(athleticFighter.canShoveOnContact, isFalse);

      expect(strongFighter.meleeKnockback, equals(192.0));
      expect(strongFighter.canShoveOnContact, isTrue);

      expect(apexFighter.strengthMod, equals(5));
      expect(apexFighter.meleeKnockback, equals(320.0));
      expect(apexFighter.canShoveOnContact, isTrue);
    });
  });

  group('Training Dummy Platform Edge Detection & Falling Physics', () {
    late ArenaMapComponent arena;
    late DummyEnemyComponent dummy;
    final platformRect = Rect.fromLTWH(960 - 300, 540 - 155, 200, 20);

    setUp(() {
      arena = ArenaMapComponent(arenaWidth: 960, arenaHeight: 540);
      dummy = DummyEnemyComponent(
        position: Vector2(960 - 200, 540 - 155 - 28),
        arena: arena,
      );
    });

    test('Dummy starts stable on platform and resists zero knockback', () {
      dummy.update(0.016);
      expect(dummy.isOnGround, isTrue);
      expect(
        dummy.position.y,
        closeTo(platformRect.top - dummy.size.y / 2, 0.1),
      );
      expect(dummy.hasFallenOffPlatform, isFalse);

      dummy.applyKnockback(forceX: 0.0);
      dummy.update(0.1);
      expect(dummy.position.x, equals(960 - 200));
      expect(dummy.isOnGround, isTrue);
    });

    test('Apex 20 STR knockback propels dummy off the platform to the ground floor', () {
      expect(dummy.isOnGround, isTrue);

      // Impart 20 STR knockback towards the left platform edge
      dummy.applyKnockback(forceX: -320.0);
      expect(dummy.velocity.x, equals(-320.0));

      // Simulate physics ticks until dummy slides past the platform edge (x < 660)
      for (int i = 0; i < 30; i++) {
        dummy.update(0.02);
      }

      // Dummy has slid past the left edge of the platform
      expect(dummy.position.x, lessThan(platformRect.left));

      // Since it is past the edge, gravity pulls it down (falling)
      for (int i = 0; i < 50; i++) {
        dummy.update(0.02);
      }

      // Dummy must have landed on the solid ground floor
      final expectedGroundY = arena.groundY - dummy.size.y / 2;
      expect(dummy.position.y, closeTo(expectedGroundY, 1.0));
      expect(dummy.isOnGround, isTrue);
      expect(dummy.hasFallenOffPlatform, isTrue);
    });

    test(
      'Player contact pushing with STR 20 moves dummy and pushes it off edge',
      () {
        final strongPlayer = CharacterStats.fighterProtagonist().copyWith(
          strength: 20,
        );
        final weakPlayer = CharacterStats.fighterProtagonist().copyWith(
          strength: 10,
        );
        final combat = PlayerCombatController();

        final playerPos = Vector2(dummy.position.x - 30, dummy.position.y);
        final initialDummyX = dummy.position.x;

        // Weak player cannot push dummy on contact
        combat.resolveEnemyContactPush(
          playerPosition: playerPos,
          playerSize: Vector2(48, 52),
          stats: weakPlayer,
          playerVelocityX: 1.0,
          dt: 0.1,
          enemies: [dummy],
        );
        expect(dummy.position.x, equals(initialDummyX));

        // Strong 20 STR player pushes dummy on contact
        combat.resolveEnemyContactPush(
          playerPosition: playerPos,
          playerSize: Vector2(48, 52),
          stats: strongPlayer,
          playerVelocityX: 1.0,
          dt: 0.5,
          enemies: [dummy],
        );
        expect(dummy.position.x, greaterThan(initialDummyX));
      },
    );

    test('Slash attack by STR 20 character imparts knockback and shoves dummy off platform', () {
      final apexPlayer = CharacterStats.fighterProtagonist().copyWith(
        strength: 20,
      );
      final combat = PlayerCombatController();

      // Position player to the left of the dummy within melee reach
      final playerPos = Vector2(dummy.position.x - 40, dummy.position.y);

      combat.resolveSlash(
        targetPos: dummy.position.clone(),
        playerPosition: playerPos,
        stats: apexPlayer,
        enemies: [dummy],
        onSpawnComponent: (_) {},
      );

      // Dummy received knockback away from player (to the right)
      expect(dummy.velocity.x, equals(320.0));

      // Simulate physics ticks until dummy slides off the right platform edge
      for (int i = 0; i < 30; i++) {
        dummy.update(0.02);
      }
      expect(dummy.position.x, greaterThan(platformRect.right));

      // Free fall to the arena floor
      for (int i = 0; i < 50; i++) {
        dummy.update(0.02);
      }

      final expectedGroundY = arena.groundY - dummy.size.y / 2;
      expect(dummy.position.y, closeTo(expectedGroundY, 1.0));
      expect(dummy.isOnGround, isTrue);
      expect(dummy.hasFallenOffPlatform, isTrue);
    });
  });
}
