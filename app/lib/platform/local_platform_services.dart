import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/platform/platform_services.dart';

class LocalPlatformServices implements PlatformServices {
  static const _pendingStatisticsKey = 'combat_statistics_pending_v1';

  @override
  bool get isAvailable => false;

  @override
  Future<void> unlockAchievement(String achievementId) async {}

  @override
  Future<void> saveCloudData(String key, Map<String, dynamic> data) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('local_cache_$key', jsonEncode(data));
  }

  @override
  Future<Map<String, dynamic>?> loadCloudData(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString('local_cache_$key');
    return value == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  @override
  Future<bool> syncCombatStatistics(CombatStatistics statistics) async {
    final preferences = await SharedPreferences.getInstance();
    final values = preferences.getStringList(_pendingStatisticsKey) ?? [];
    values.add(jsonEncode(statistics.toJson()));
    await preferences.setStringList(_pendingStatisticsKey, values);
    return false;
  }

  @override
  Future<List<CombatStatistics>> loadPendingCombatStatistics() async {
    final preferences = await SharedPreferences.getInstance();
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