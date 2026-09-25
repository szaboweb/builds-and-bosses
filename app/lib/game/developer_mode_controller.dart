import 'package:flutter/foundation.dart';

class DeveloperModeController {
  final ValueNotifier<bool> enabled;

  DeveloperModeController({bool initiallyEnabled = kDebugMode})
    : enabled = ValueNotifier<bool>(initiallyEnabled);

  void toggle() => enabled.value = !enabled.value;
}