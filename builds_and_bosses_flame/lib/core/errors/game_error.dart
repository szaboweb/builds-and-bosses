/// Standardized, machine-readable Error Codes for Builds & Bosses.
/// Enables consistent diagnostic reporting, telemetry, and debugging.
enum GameErrorCode {
  // Action economy and tactical planning errors (1000 - 1099)
  insufficientAP(1001, 'Insufficient Action Points to perform or queue action'),
  actionQueueFull(1002, 'Tactical action queue has reached maximum capacity'),
  invalidTargetPosition(1003, 'Target coordinate is out of bounds or unreachable'),
  targetNotFound(1004, 'No valid target entity found at specified position'),
  invalidPhaseTransition(1005, 'Illegal game phase state transition requested'),
  illegalActionState(1006, 'Action cannot be executed in the current entity state'),

  // Character builder and stat errors (1100 - 1199)
  pointBuyBudgetExceeded(1101, 'Point buy budget exceeded for attribute allocation'),
  invalidAttributeScore(1102, 'Attribute score is outside the valid range [8, 18]'),

  // Combat system errors (1200 - 1299)
  attackerDead(1201, 'Attacker cannot perform attack while dead'),
  defenderDead(1202, 'Target defender is already defeated'),

  // General system errors (9000 - 9999)
  unknown(9999, 'An unexpected internal game error occurred');

  final int code;
  final String defaultMessage;

  const GameErrorCode(this.code, this.defaultMessage);

  @override
  String toString() => 'ERR-$code: $name ($defaultMessage)';
}

/// Structured game exception with error code, message, and diagnostic context.
class GameException implements Exception {
  final GameErrorCode code;
  final String message;
  final Map<String, dynamic>? context;
  final DateTime timestamp;

  GameException({
    required this.code,
    String? message,
    this.context,
    DateTime? timestamp,
  })  : message = message ?? code.defaultMessage,
        timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => '[GameException ERR-${code.code}] $message';
}
