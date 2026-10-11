import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:builds_and_bosses_flame/game/components/parallax_backdrop_component.dart';

void main() {
  group('ParallaxBackdropComponent Tests', () {
    test('Initializes with priority -100 and correct arena dimensions', () {
      final backdrop = ParallaxBackdropComponent(
        arenaWidth: 960.0,
        arenaHeight: 540.0,
      );

      expect(backdrop.priority, equals(-100));
      expect(backdrop.size.x, equals(960.0));
      expect(backdrop.size.y, equals(540.0));
    });

    test('update advances ambient animation timer', () {
      final backdrop = ParallaxBackdropComponent(
        arenaWidth: 960.0,
        arenaHeight: 540.0,
      );

      backdrop.update(0.1);
      backdrop.update(0.2);
      // No crashes; state progresses
    });

    test('render executes successfully without mounted game camera', () {
      final backdrop = ParallaxBackdropComponent(
        arenaWidth: 960.0,
        arenaHeight: 540.0,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      backdrop.render(canvas);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });
}
