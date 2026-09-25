import '../actions/game_action.dart';

class DebugReplaySnapshot {
  final int seed;
  final String ruleset;
  final String heroName;
  final String bossId;
  final List<Map<String, dynamic>> actions;
  final String? outcome;

  const DebugReplaySnapshot({
    required this.seed,
    required this.ruleset,
    required this.heroName,
    required this.bossId,
    required this.actions,
    this.outcome,
  });

  Map<String, dynamic> toJson() => {
    'seed': seed,
    'ruleset': ruleset,
    'hero_name': heroName,
    'boss_id': bossId,
    'actions': actions,
    'outcome': outcome,
  };

  factory DebugReplaySnapshot.fromJson(Map<String, dynamic> json) {
    return DebugReplaySnapshot(
      seed: json['seed'] as int,
      ruleset: json['ruleset'] as String,
      heroName: json['hero_name'] as String,
      bossId: json['boss_id'] as String,
      actions: (json['actions'] as List<dynamic>)
          .map((action) => Map<String, dynamic>.from(action as Map))
          .toList(),
      outcome: json['outcome'] as String?,
    );
  }
}

class DebugReplayRecorder {
  final int seed;
  final String ruleset;
  final String heroName;
  final String bossId;
  final List<Map<String, dynamic>> _actions = [];
  String? _outcome;

  DebugReplayRecorder({
    required this.seed,
    required this.ruleset,
    required this.heroName,
    required this.bossId,
  });

  void recordAction(GameAction action) {
    final entry = <String, dynamic>{
      'type': action.type.name,
      'name': action.name,
      'ap_cost': action.apCost,
    };
    if (action is SlashAction) {
      entry['target_x'] = action.targetPosition.x;
      entry['target_y'] = action.targetPosition.y;
    } else if (action is RangedAction) {
      entry['target_x'] = action.targetPosition.x;
      entry['target_y'] = action.targetPosition.y;
    } else if (action is SpellAction) {
      entry['target_x'] = action.targetPosition.x;
      entry['target_y'] = action.targetPosition.y;
    }
    _actions.add(entry);
  }

  void complete(String outcome) => _outcome = outcome;

  DebugReplaySnapshot get snapshot => DebugReplaySnapshot(
    seed: seed,
    ruleset: ruleset,
    heroName: heroName,
    bossId: bossId,
    actions: List.unmodifiable(_actions),
    outcome: _outcome,
  );
}