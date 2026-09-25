import 'package:flutter/foundation.dart';

class CombatTimerController {
  final ValueNotifier<Duration> elapsedNotifier =
      ValueNotifier<Duration>(Duration.zero);
  bool _running = true;

  Duration get elapsed => elapsedNotifier.value;
  bool get isRunning => _running;

  void update(double deltaSeconds) {
    if (!_running || deltaSeconds <= 0) return;
    final milliseconds =
        elapsed.inMilliseconds + (deltaSeconds * 1000).round();
    elapsedNotifier.value = Duration(milliseconds: milliseconds);
  }

  void pause() => _running = false;

  void resume() => _running = true;

  void reset() {
    _running = true;
    elapsedNotifier.value = Duration.zero;
  }

  void stop() => _running = false;
}