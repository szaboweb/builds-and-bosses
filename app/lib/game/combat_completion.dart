import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/combat/combat_logger.dart';
import '../core/platform/platform_services.dart';

class CombatCompletion {
  final PlatformServices services;
  final Duration timeout;
  final ValueNotifier<String?> error = ValueNotifier(null);
  bool _disposed = false;

  CombatCompletion(this.services, {this.timeout = const Duration(seconds: 10)});

  Future<void> record(CombatStatistics statistics) async {
    if (!_disposed) error.value = null;
    await _perform('Combat statistics', () async {
      await services.syncCombatStatistics(statistics);
    });
    if (statistics.outcome == 'victory' && services.isAvailable) {
      await _perform(
        'Achievement',
        () => services.unlockAchievement('training_golem_defeated'),
      );
    }
  }

  Future<void> _perform(
    String operation,
    Future<void> Function() action,
  ) async {
    try {
      await action().timeout(timeout);
    } on Exception catch (failure) {
      _report(operation, failure);
    } on StateError catch (failure) {
      _report(operation, failure);
    }
  }

  void _report(String operation, Object failure) {
    final message = '$operation failed: $failure';
    CombatLogger.instance.logWarning('PERSISTENCE', message);
    if (!_disposed) error.value = message;
  }

  void dispose() {
    _disposed = true;
    error.dispose();
  }
}
