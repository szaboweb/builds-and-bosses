import 'package:flutter/foundation.dart';
import '../dnd/character_stats.dart';
import '../dnd/combat_engine.dart';
import '../actions/game_action.dart';
import '../errors/game_error.dart';

enum LogLevel {
  debug,
  info,
  warn,
  error,
  combat,
}

/// A structured log entry capturing game and combat events.
class CombatLogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String category;
  final String message;
  final Map<String, dynamic>? data;

  CombatLogEntry({
    DateTime? timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.data,
  }) : timestamp = timestamp ?? DateTime.now();

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  @override
  String toString() {
    final lvl = level.name.toUpperCase().padRight(6);
    return '[$formattedTime] [$lvl] [$category] $message';
  }
}

/// Centralized, structured Combat and System Logger for Builds & Bosses.
/// Provides in-memory history, observable event stream, and formatted diagnostic output.
class CombatLogger {
  static final CombatLogger instance = CombatLogger._internal();

  CombatLogger._internal();

  // Test constructor to allow fresh instances
  @visibleForTesting
  CombatLogger.createFresh();

  static const int maxHistorySize = 500;
  final List<CombatLogEntry> _history = [];

  final ValueNotifier<CombatLogEntry?> lastEntryNotifier = ValueNotifier(null);

  List<CombatLogEntry> get history => List.unmodifiable(_history);

  /// General purpose logging method
  void log({
    required LogLevel level,
    required String category,
    required String message,
    Map<String, dynamic>? data,
  }) {
    final entry = CombatLogEntry(
      level: level,
      category: category,
      message: message,
      data: data,
    );

    if (_history.length >= maxHistorySize) {
      _history.removeAt(0);
    }
    _history.add(entry);
    lastEntryNotifier.value = entry;

    if (kDebugMode) {
      debugPrint(entry.toString());
    }
  }

  /// Logs a detailed D&D combat attack resolution
  void logCombatAttack({
    required CharacterStats attacker,
    required CharacterStats defender,
    required CombatResult result,
  }) {
    final rollType = result.isCritical
        ? 'CRITICAL HIT'
        : (result.isHit ? 'HIT' : 'MISS');

    final message = '${attacker.name} attacks ${defender.name} -> '
        'd20: ${result.rawD20Roll} + ${attacker.meleeAttackBonus} = ${result.totalAttackRoll} '
        'vs AC ${result.targetAC} [$rollType] '
        '-> Damage: ${result.damageDealt} '
        '(${defender.name} HP: ${defender.currentHp}/${defender.maxHp})';

    log(
      level: LogLevel.combat,
      category: 'COMBAT',
      message: message,
      data: {
        'attacker': attacker.name,
        'defender': defender.name,
        'rawD20': result.rawD20Roll,
        'attackBonus': attacker.meleeAttackBonus,
        'totalRoll': result.totalAttackRoll,
        'targetAC': result.targetAC,
        'isHit': result.isHit,
        'isCritical': result.isCritical,
        'damageDealt': result.damageDealt,
        'defenderHpAfter': defender.currentHp,
      },
    );
  }

  /// Logs a healing effect
  void logCombatHeal({
    required CharacterStats target,
    required int healAmount,
    required String abilityName,
  }) {
    final message = '${target.name} uses $abilityName -> '
        '+$healAmount HP (Current HP: ${target.currentHp}/${target.maxHp})';

    log(
      level: LogLevel.combat,
      category: 'COMBAT',
      message: message,
      data: {
        'target': target.name,
        'ability': abilityName,
        'healAmount': healAmount,
        'currentHp': target.currentHp,
        'maxHp': target.maxHp,
      },
    );
  }

  /// Logs an action queued or executed in Tactical Mode
  void logTacticalAction({
    required String eventType, // e.g., 'QUEUED', 'UNDONE', 'EXECUTED'
    required GameAction action,
    required int spentAP,
    required int remainingAP,
  }) {
    final message = '[$eventType] ${action.name} (${action.apCost} AP) -> '
        'Remaining AP: $remainingAP';

    log(
      level: LogLevel.info,
      category: 'TACTICAL',
      message: message,
      data: {
        'eventType': eventType,
        'actionName': action.name,
        'apCost': action.apCost,
        'spentAP': spentAP,
        'remainingAP': remainingAP,
      },
    );
  }

  /// Logs a game phase transition
  void logPhaseChange({required String fromPhase, required String toPhase}) {
    log(
      level: LogLevel.info,
      category: 'PHASE',
      message: 'Phase transition: $fromPhase -> $toPhase',
      data: {'from': fromPhase, 'to': toPhase},
    );
  }

  /// Logs a system or gameplay warning
  void logWarning(String category, String message, [Map<String, dynamic>? data]) {
    log(
      level: LogLevel.warn,
      category: category,
      message: message,
      data: data,
    );
  }

  /// Logs a system or gameplay error
  void logError(String category, String message, [Object? error, StackTrace? stackTrace]) {
    log(
      level: LogLevel.error,
      category: category,
      message: error != null ? '$message: $error' : message,
      data: {
        if (error != null) 'error': error.toString(),
        if (stackTrace != null) 'stack': stackTrace.toString(),
      },
    );
  }

  /// Logs a structured GameException
  void logGameException(GameException exception) {
    log(
      level: LogLevel.error,
      category: 'ERROR',
      message: '[${exception.code.name}] ${exception.message}',
      data: {
        'errorCode': exception.code.code,
        'errorName': exception.code.name,
        if (exception.context != null) ...exception.context!,
      },
    );
  }

  /// Logs character build changes applied via Character Builder / Tervezőasztal
  void logBuildChange({
    required CharacterStats oldStats,
    required CharacterStats newStats,
  }) {
    final message = 'Build applied for ${newStats.name}: '
        'STR: ${oldStats.strength} -> ${newStats.strength}, '
        'DEX: ${oldStats.dexterity} -> ${newStats.dexterity}, '
        'CON: ${oldStats.constitution} -> ${newStats.constitution} | '
        'Jump: ${oldStats.jumpVelocity.toStringAsFixed(1)} -> ${newStats.jumpVelocity.toStringAsFixed(1)} px/s '
        '(${oldStats.maxJumpHeight.toStringAsFixed(0)} -> ${newStats.maxJumpHeight.toStringAsFixed(0)} px peak) | '
        'HP: ${oldStats.maxHp} -> ${newStats.maxHp}';

    log(
      level: LogLevel.info,
      category: 'BUILD',
      message: message,
      data: {
        'character': newStats.name,
        'oldStr': oldStats.strength,
        'newStr': newStats.strength,
        'oldDex': oldStats.dexterity,
        'newDex': newStats.dexterity,
        'oldCon': oldStats.constitution,
        'newCon': newStats.constitution,
        'newJumpVelocity': newStats.jumpVelocity,
        'newMaxJumpHeight': newStats.maxJumpHeight,
        'newMaxHp': newStats.maxHp,
      },
    );
  }

  /// Returns a full text export of the log history
  String exportFormattedLog() {
    return _history.map((e) => e.toString()).join('\n');
  }

  /// Clears the history buffer
  void clear() {
    _history.clear();
    lastEntryNotifier.value = null;
  }
}
