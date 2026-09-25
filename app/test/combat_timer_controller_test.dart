import 'package:flutter_test/flutter_test.dart';

import 'package:builds_and_bosses_flame/core/combat/combat_timer_controller.dart';

void main() {
  test('CombatTimerController pauses, resumes, resets and stops', () {
    final timer = CombatTimerController();
    timer.update(1.0);
    expect(timer.elapsed.inMilliseconds, equals(1000));

    timer.pause();
    timer.update(2.0);
    expect(timer.elapsed.inMilliseconds, equals(1000));

    timer.resume();
    timer.update(0.5);
    expect(timer.elapsed.inMilliseconds, equals(1500));

    timer.stop();
    timer.update(1.0);
    expect(timer.elapsed.inMilliseconds, equals(1500));

    timer.reset();
    expect(timer.elapsed, equals(Duration.zero));
    expect(timer.isRunning, isTrue);
  });
}