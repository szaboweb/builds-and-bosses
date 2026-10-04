/// Structured outcome of a combat strike.
class CombatResult {
  final bool isHit;
  final bool isCritical;
  final bool isCriticalMiss;
  final int rawD20Roll;
  final int totalAttackRoll;
  final int targetAC;
  final int damageDealt;
  final String description;

  CombatResult({
    required this.isHit,
    required this.isCritical,
    required this.isCriticalMiss,
    required this.rawD20Roll,
    required this.totalAttackRoll,
    required this.targetAC,
    required this.damageDealt,
    required this.description,
  });

  @override
  String toString() => description;
}
