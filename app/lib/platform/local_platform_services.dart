import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/platform/platform_services.dart';

class LocalPlatformServices implements PlatformServices {
  final Future<SharedPreferences> Function() _preferences;
  final Duration timeout;
  Future<void> _statisticsWrite = Future.value();

  LocalPlatformServices({
    Future<SharedPreferences> Function()? preferences,
    this.timeout = const Duration(seconds: 10),
  }) : _preferences = preferences ?? SharedPreferences.getInstance;

  Future<SharedPreferences> _getPreferences() =>
      _preferences().timeout(timeout);

  static const _pendingStatisticsKey = 'combat_statistics_pending_v1';

  @override
  bool get isAvailable => false;

  @override
  Future<void> unlockAchievement(String achievementId) async {}

  @override
  Future<void> saveCloudData(String key, Map<String, dynamic> data) async {
    final preferences = await _getPreferences();
    final saved = await preferences
        .setString('local_cache_$key', jsonEncode(data))
        .timeout(timeout);
    if (!saved) throw StateError('Local save failed: $key');
  }

  @override
  Future<Map<String, dynamic>?> loadCloudData(String key) async {
    final preferences = await _getPreferences();
    final value = preferences.getString('local_cache_$key');
    return value == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  @override
  Future<bool> syncCombatStatistics(CombatStatistics statistics) async {
    final previous = _statisticsWrite;
    final release = Completer<void>();
    _statisticsWrite = release.future;
    await previous;
    try {
      final preferences = await _getPreferences();
      final values = List<String>.from(
        preferences.getStringList(_pendingStatisticsKey) ?? [],
      );
      values.add(jsonEncode(statistics.toJson()));
      final saved = await preferences
          .setStringList(_pendingStatisticsKey, values)
          .timeout(timeout);
      if (!saved) throw StateError('Combat statistics local save failed');
      return false;
    } finally {
      release.complete();
    }
  }

  @override
  Future<List<CombatStatistics>> loadPendingCombatStatistics() async {
    final preferences = await _getPreferences();
    final values = preferences.getStringList(_pendingStatisticsKey) ?? [];
    return values.map((value) {
      final json = Map<String, dynamic>.from(jsonDecode(value) as Map);
      return CombatStatistics(
        runId: json['run_id'] as String,
        completedAt: DateTime.parse(json['completed_at'] as String),
        heroName: json['hero_name'] as String,
        bossId: json['boss_id'] as String,
        outcome: json['outcome'] as String,
        durationMs: json['duration_ms'] as int,
      );
    }).toList();
  }
}
