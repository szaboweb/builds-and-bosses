abstract interface class PlatformServices {
  bool get isAvailable;

  Future<void> unlockAchievement(String achievementId);

  Future<void> saveCloudData(String key, Map<String, dynamic> data);

  Future<Map<String, dynamic>?> loadCloudData(String key);
}

class LocalPlatformServices implements PlatformServices {
  final Map<String, Map<String, dynamic>> _localSaves = {};

  @override
  bool get isAvailable => false;

  @override
  Future<void> unlockAchievement(String achievementId) async {}

  @override
  Future<void> saveCloudData(String key, Map<String, dynamic> data) async {
    _localSaves[key] = Map<String, dynamic>.from(data);
  }

  @override
  Future<Map<String, dynamic>?> loadCloudData(String key) async {
    final data = _localSaves[key];
    return data == null ? null : Map<String, dynamic>.from(data);
  }
}
