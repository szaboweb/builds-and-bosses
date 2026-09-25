import 'package:flutter_test/flutter_test.dart';
import 'package:builds_and_bosses_flame/core/actions/game_action.dart';
import 'package:builds_and_bosses_flame/core/combat/combat_logger.dart';
import 'package:builds_and_bosses_flame/core/dnd/character_stats.dart';
import 'package:builds_and_bosses_flame/core/dnd/combat_engine.dart';
import 'package:flame/extensions.dart';

void main() {
  group('CombatLogger Unit Tests', () {
    late CombatLogger logger;

    setUp(() {
      logger = CombatLogger.createFresh();
    });

    test('Records general structured log entry', () {
      logger.log(
        level: LogLevel.info,
        category: 'SYSTEM',
        message: 'Engine initialized',
        data: {'version': '1.0.0'},
      );

      expect(logger.history.length, equals(1));
      final entry = logger.history.first;
      expect(entry.level, equals(LogLevel.info));
      expect(entry.category, equals('SYSTEM'));
      expect(entry.message, equals('Engine initialized'));
      expect(entry.data?['version'], equals('1.0.0'));
      expect(entry.toString(), contains('[INFO  ] [SYSTEM] Engine initialized'));
    });

    test('logCombatAttack records attack rolls, AC, bonuses and damage', () {
      final attacker = CharacterStats.fighterProtagonist();
      final defender = CharacterStats.trainingDummy();

      final result = CombatResult(
        isHit: true,
        isCritical: false,
        isCriticalMiss: false,
        rawD20Roll: 14,
        totalAttackRoll: 19,
        targetAC: 13,
        damageDealt: 8,
        description: 'HIT! (19 vs 13) -> 8 dmg',
      );

      logger.logCombatAttack(
        attacker: attacker,
        defender: defender,
        result: result,
      );

      expect(logger.history.length, equals(1));
      final entry = logger.history.first;
      expect(entry.level, equals(LogLevel.combat));
      expect(entry.category, equals('COMBAT'));
      expect(entry.data?['attacker'], equals(attacker.name));
      expect(entry.data?['defender'], equals(defender.name));
      expect(entry.data?['attackBonus'], equals(attacker.meleeAttackBonus));
      expect(entry.data?['damageDealt'], equals(8));
      expect(entry.message, contains('Fighter attacks Training Golem'));
    });

    test('logCombatHeal records healing and current/max HP', () {
      final hero = CharacterStats.fighterProtagonist();
      hero.takeDamage(15);

      logger.logCombatHeal(
        target: hero,
        healAmount: 8,
        abilityName: 'Second Wind',
      );

      expect(logger.history.length, equals(1));
      final entry = logger.history.first;
      expect(entry.level, equals(LogLevel.combat));
      expect(entry.category, equals('COMBAT'));
      expect(entry.data?['healAmount'], equals(8));
      expect(entry.message, contains('Second Wind -> +8 HP'));
    });

    test('logTacticalAction records action queueing and execution', () {
      final action = SlashAction(targetPosition: Vector2(200, 300));

      logger.logTacticalAction(
        eventType: 'QUEUED',
        action: action,
        spentAP: 25,
        remainingAP: 75,
      );

      expect(logger.history.length, equals(1));
      final entry = logger.history.first;
      expect(entry.category, equals('TACTICAL'));
      expect(entry.data?['eventType'], equals('QUEUED'));
      expect(entry.data?['apCost'], equals(25));
      expect(entry.data?['remainingAP'], equals(75));
      expect(entry.message, contains('[QUEUED] Slash (25 AP)'));
    });

    test('logBuildChange records stats and jump dynamics', () {
      final oldStats = CharacterStats.fighterProtagonist();
      final newStats = oldStats.copyWith(strength: 18); // +4 mod -> higher jump

      logger.logBuildChange(oldStats: oldStats, newStats: newStats);

      expect(logger.history.length, equals(1));
      final entry = logger.history.first;
      expect(entry.category, equals('BUILD'));
      expect(entry.data?['oldStr'], equals(16));
      expect(entry.data?['newStr'], equals(18));
      expect(entry.message, contains('STR: 16 -> 18'));
    });

    test('History buffer enforces maxHistorySize of 500 without leaking memory', () {
      for (int i = 0; i < 550; i++) {
        logger.log(
          level: LogLevel.debug,
          category: 'TEST',
          message: 'Entry $i',
        );
      }

      expect(logger.history.length, equals(CombatLogger.maxHistorySize));
      // First entry should now be #50 (oldest 50 were purged FIFO)
      expect(logger.history.first.message, equals('Entry 50'));
      expect(logger.history.last.message, equals('Entry 549'));
    });

    test('exportFormattedLog returns newline separated logs', () {
      logger.log(level: LogLevel.info, category: 'A', message: 'First');
      logger.log(level: LogLevel.info, category: 'B', message: 'Second');

      final exported = logger.exportFormattedLog();
      expect(exported, contains('[A] First'));
      expect(exported, contains('[B] Second'));
      expect(exported.split('\n').length, equals(2));
    });

    test('clear empties the history buffer and resets notifier', () {
      logger.log(level: LogLevel.info, category: 'A', message: 'First');
      expect(logger.history.length, equals(1));

      logger.clear();
      expect(logger.history.isEmpty, isTrue);
      expect(logger.lastEntryNotifier.value, isNull);
    });
  });
}
