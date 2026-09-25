import 'package:flutter/foundation.dart';
import 'game_action.dart';

/// Manages the queue of planned actions and Action Point (AP) economy.
class ActionQueue extends ChangeNotifier {
  final int maxAP;
  final List<GameAction> _actions = [];

  ActionQueue({this.maxAP = 100});

  List<GameAction> get actions => List.unmodifiable(_actions);

  /// Calculate the total AP spent by planned actions.
  int get spentAP => _actions.fold(0, (sum, action) => sum + action.apCost);

  /// Remaining AP available for planning.
  int get remainingAP => (maxAP - spentAP).clamp(0, maxAP);

  bool get isEmpty => _actions.isEmpty;
  bool get isNotEmpty => _actions.isNotEmpty;
  int get count => _actions.length;

  /// Check whether an action can be afforded.
  bool canAfford(GameAction action) {
    return spentAP + action.apCost <= maxAP;
  }

  /// Try to add an action. Returns true if added, false if not enough AP.
  bool tryAdd(GameAction action) {
    if (!canAfford(action)) {
      return false;
    }
    _actions.add(action);
    notifyListeners();
    return true;
  }

  /// Remove the last planned action (Undo).
  GameAction? undo() {
    if (_actions.isEmpty) return null;
    final removed = _actions.removeLast();
    notifyListeners();
    return removed;
  }

  /// Remove a specific action at index.
  void removeAt(int index) {
    if (index >= 0 && index < _actions.length) {
      _actions.removeAt(index);
      notifyListeners();
    }
  }

  /// Clear all queued actions and reset AP.
  void clear() {
    _actions.clear();
    notifyListeners();
  }
}
