class CombatStatistics {
  final String runId;
  final DateTime completedAt;
  final String heroName;
  final String bossId;
  final String outcome;
  final int durationMs;

  const CombatStatistics({
    required this.runId,
    required this.completedAt,
    required this.heroName,
    required this.bossId,
    required this.outcome,
    required this.durationMs,
  });

  Map<String, dynamic> toJson() => {
    'run_id': runId,
    'completed_at': completedAt.toUtc().toIso8601String(),
    'hero_name': heroName,
    'boss_id': bossId,
    'outcome': outcome,
    'duration_ms': durationMs,
  };
}

abstract interface class PlatformServices {
  bool get isAvailable;

  Future<void> unlockAchievement(String achievementId);

  Future<void> saveCloudData(String key, Map<String, dynamic> data);

  Future<Map<String, dynamic>?> loadCloudData(String key);

  Future<bool> syncCombatStatistics(CombatStatistics statistics);

  Future<List<CombatStatistics>> loadPendingCombatStatistics();
}
