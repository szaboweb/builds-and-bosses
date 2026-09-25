import 'dart:convert';

import 'package:flame/extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:builds_and_bosses_flame/core/actions/game_action.dart';
import 'package:builds_and_bosses_flame/core/debug/debug_replay.dart';

void main() {
  test('debug replay snapshot round-trips and preserves action target', () {
    final recorder = DebugReplayRecorder(
      seed: 12345,
      ruleset: 'dnd2024',
      heroName: 'Fighter',
      bossId: 'training_golem',
    );
    recorder.recordAction(
      SlashAction(targetPosition: Vector2(2200, 700)),
    );
    recorder.complete('victory');

    final restored = DebugReplaySnapshot.fromJson(
      jsonDecode(jsonEncode(recorder.snapshot.toJson()))
          as Map<String, dynamic>,
    );
    expect(restored.seed, equals(12345));
    expect(restored.actions.single['target_x'], equals(2200));
    expect(restored.outcome, equals('victory'));
  });
}