import 'dart:ui' as ui;

import 'package:builds_and_bosses_flame/core/inventory/godot_sample_equipment.dart';
import 'package:builds_and_bosses_flame/game/components/player_component.dart';
import 'package:builds_and_bosses_flame/game/tactical_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'equipped fighter layers render, follow poses and disappear on removal',
    (tester) async {
      final game = TacticalModeGame();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GameWidget(game: game)),
        ),
      );
      await tester.runAsync(() => game.ready());
      final player = game.player;
      final stats = player.stats;
      final physicsSize = player.size.clone();
      final gear = godotSampleEquipmentSets.single.items;

      Future<List<int>> pixels() async {
        final result = await tester.runAsync(() async {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder)..translate(16, 16);
          player.render(canvas);
          final picture = recorder.endRecording();
          final image = await picture.toImage(96, 96);
          final bytes = await image.toByteData();
          if (bytes == null) {
            throw StateError('Rendered fighter pixels missing');
          }
          final result = bytes.buffer.asUint8List().toList();
          image.dispose();
          picture.dispose();
          return result;
        });
        return result!;
      }

      final bare = await pixels();
      for (final item in gear) {
        await tester.runAsync(() => player.setEquipment([item]));
        expect(player.equippedItems.single, same(item));
        expect(player.equipmentSprites.single.srcPosition.x, 0);
        expect(
          await pixels(),
          isNot(equals(bare)),
          reason: '${item.id} must be visible',
        );
      }
      await tester.runAsync(() => player.setEquipment(const []));
      expect(await pixels(), equals(bare));
      await tester.runAsync(() => player.setEquipment(gear));
      expect(player.equipmentSprites, hasLength(3));
      expect(await pixels(), isNot(equals(bare)));
      player.velocity.x = 1;
      player.update(0.1);
      for (final layer in player.equipmentSprites) {
        expect(layer.srcPosition, player.sprite!.srcPosition);
        expect(layer.srcSize, player.sprite!.srcSize);
      }
      player.isFacingLeft = true;
      player.verticalFlightInput = -1;
      player.update(0.1);
      for (final layer in player.equipmentSprites) {
        expect(layer.srcPosition.x, 4 * 64);
      }
      expect(player.stats, same(stats));
      expect(player.size, physicsSize);
      await tester.runAsync(() => player.setEquipment(const []));
      expect(player.equipmentSprites, isEmpty);
      expect(player.equippedItems, isEmpty);
      player.verticalFlightInput = 0;
      player.velocity.x = 0;
      player.isFacingLeft = false;
      player.isOnGround = true;
      player.update(0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Godot fighter loads and follows arrow movement and flight', (
    tester,
  ) async {
    final game = TacticalModeGame();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GameWidget(game: game)),
      ),
    );
    await tester.runAsync(() => game.ready());
    await tester.pump();
    final player = game.player;
    expect(
      PlayerComponent.characterSheetPath,
      PlayerComponent.godotFighterSheetPath,
    );
    expect(player.sprite, isNotNull);
    expect(player.sprite!.srcSize.x, 64);
    expect(player.sprite!.srcPosition.x, 0);
    final size = player.size.clone();
    final startX = player.position.x;

    game.onKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.arrowRight,
        logicalKey: LogicalKeyboardKey.arrowRight,
        timeStamp: Duration.zero,
      ),
      {LogicalKeyboardKey.arrowRight},
    );
    player.update(0.04);
    expect(player.position.x, greaterThan(startX));
    expect(player.isFacingLeft, isFalse);
    final firstWalkFrame = player.sprite!.srcPosition.x;
    player.update(0.05);
    expect(player.sprite!.srcPosition.x, isNot(firstWalkFrame));
    expect(player.sprite!.srcPosition.x, greaterThanOrEqualTo(64));
    expect(player.sprite!.srcPosition.x, lessThanOrEqualTo(12 * 64));

    game.onKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.arrowLeft,
        logicalKey: LogicalKeyboardKey.arrowLeft,
        timeStamp: Duration.zero,
      ),
      {LogicalKeyboardKey.arrowLeft},
    );
    player.update(0.02);
    expect(player.isFacingLeft, isTrue);

    game.onKeyEvent(
      const KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.arrowLeft,
        logicalKey: LogicalKeyboardKey.arrowLeft,
        timeStamp: Duration.zero,
      ),
      {},
    );
    player.update(0.02);
    expect(player.sprite!.srcPosition.x, 0);

    final startY = player.position.y;
    game.onKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.arrowUp,
        logicalKey: LogicalKeyboardKey.arrowUp,
        timeStamp: Duration.zero,
      ),
      {LogicalKeyboardKey.arrowUp},
    );
    player.update(0.1);
    expect(player.position.y, lessThan(startY));
    expect(player.isOnGround, isFalse);
    expect(player.sprite!.srcPosition.x, 4 * 64);
    expect(
      player.size,
      size,
      reason: 'Visual replacement must not change physics bounds',
    );

    game.onKeyEvent(
      const KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.arrowUp,
        logicalKey: LogicalKeyboardKey.arrowUp,
        timeStamp: Duration.zero,
      ),
      {},
    );
    for (var step = 0; step < 30; step++) {
      player.update(0.05);
    }
    expect(player.isOnGround, isTrue);
    expect(player.sprite!.srcPosition.x, 0);
    game.onKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.space,
        logicalKey: LogicalKeyboardKey.space,
        timeStamp: Duration.zero,
      ),
      {LogicalKeyboardKey.space},
    );
    expect(player.velocity.y, lessThan(0));
    player.update(0.05);
    expect(player.isOnGround, isFalse);
    expect(player.sprite!.srcPosition.x, 4 * 64);

    final originalPath = PlayerComponent.characterSheetPath;
    try {
      PlayerComponent.characterSheetPath =
          'characters/stickman_13/walk13_rendered.png';
      await tester.runAsync(player.reloadCharacterSheet);
      expect(player.sprite!.srcSize.x, 32);
      PlayerComponent.characterSheetPath = originalPath;
      await tester.runAsync(player.reloadCharacterSheet);
      expect(player.sprite!.srcSize.x, 64);
      expect(player.sprite!.srcPosition.x, 0);
    } finally {
      PlayerComponent.characterSheetPath = originalPath;
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
