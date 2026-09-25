import 'package:flutter_test/flutter_test.dart';
import 'package:builds_and_bosses_flame/core/combat/combat_logger.dart';
import 'package:builds_and_bosses_flame/core/errors/game_error.dart';

void main() {
  group('GameErrorCode and GameException Tests', () {
    test('Error codes map to documented numeric codes and messages', () {
      expect(GameErrorCode.insufficientAP.code, equals(1001));
      expect(GameErrorCode.actionQueueFull.code, equals(1002));
      expect(GameErrorCode.invalidTargetPosition.code, equals(1003));
      expect(GameErrorCode.pointBuyBudgetExceeded.code, equals(1101));
      expect(GameErrorCode.invalidAttributeScore.code, equals(1102));

      expect(
        GameErrorCode.insufficientAP.toString(),
        contains('ERR-1001: insufficientAP'),
      );
    });

    test('GameException formats cleanly with code and context', () {
      final exception = GameException(
        code: GameErrorCode.insufficientAP,
        message: 'Needed 25 AP but only had 10 AP',
        context: {'currentAP': 10, 'requiredAP': 25},
      );

      expect(exception.code, equals(GameErrorCode.insufficientAP));
      expect(exception.message, equals('Needed 25 AP but only had 10 AP'));
      expect(exception.context?['currentAP'], equals(10));
      expect(exception.toString(), contains('[GameException ERR-1001]'));
    });

    test('CombatLogger logs GameException accurately', () {
      final logger = CombatLogger.createFresh();
      final exception = GameException(
        code: GameErrorCode.invalidTargetPosition,
        context: {'x': -50, 'y': 999},
      );

      logger.logGameException(exception);

      expect(logger.history.length, equals(1));
      final entry = logger.history.first;
      expect(entry.level, equals(LogLevel.error));
      expect(entry.category, equals('ERROR'));
      expect(entry.data?['errorCode'], equals(1003));
      expect(entry.data?['errorName'], equals('invalidTargetPosition'));
      expect(entry.data?['x'], equals(-50));
    });
  });
}
