import 'game_action.dart';

class ActionCooldowns {
  final Map<ActionEconomyType, double> _remaining = {
    for (final type in ActionEconomyType.values) type: 0,
  };
  final Map<ActionType, double> _abilityRemaining = {};

  double remainingFor(ActionEconomyType type) => _remaining[type] ?? 0;

  double remainingForAbility(ActionType type) => _abilityRemaining[type] ?? 0;

  bool canUse(GameAction action) {
    return remainingFor(action.economyType) <= 0 &&
        remainingForAbility(action.type) <= 0;
  }

  void start(GameAction action, double duration) {
    _remaining[action.economyType] = duration;
    _abilityRemaining[action.type] = duration;
  }

  void update(double deltaSeconds) {
    for (final type in _remaining.keys) {
      _remaining[type] = _decrement(_remaining[type] ?? 0, deltaSeconds);
    }
    for (final type in _abilityRemaining.keys.toList()) {
      _abilityRemaining[type] = _decrement(
        _abilityRemaining[type] ?? 0,
        deltaSeconds,
      );
    }
  }

  double _decrement(double remaining, double deltaSeconds) {
    final next = remaining - deltaSeconds;
    return next <= 0.000001 ? 0 : next;
  }
}
