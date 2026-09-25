import 'package:flame/extensions.dart';

/// Available action types in the Tactical Mode planning phase.
enum ActionType { move, slash, ranged, spell, dash, heal }

enum ActionEconomyType { action, bonusAction, reaction }

/// Abstract base class for a planable action.
abstract class GameAction {
  final ActionType type;
  final String name;
  final String description;
  final int apCost;
  final ActionEconomyType economyType;

  GameAction({
    required this.type,
    required this.name,
    required this.description,
    required this.apCost,
    this.economyType = ActionEconomyType.action,
  });
}

/// Movement action towards a target coordinate on the arena.
class MoveAction extends GameAction {
  final Vector2 targetPosition;

  MoveAction({required this.targetPosition, int? customCost})
    : super(
        type: ActionType.move,
        name: 'Move',
        description: 'Step to target location',
        apCost: customCost ?? 15,
      );
}

/// Melee attack action targeting adjacent foe.
class SlashAction extends GameAction {
  final Vector2 targetPosition;

  SlashAction({required this.targetPosition})
    : super(
        type: ActionType.slash,
        name: 'Slash',
        description: 'Melee weapon strike (1d8 + STR)',
        apCost: 25,
        economyType: ActionEconomyType.action,
      );
}

class SpellAction extends GameAction {
  final Vector2 targetPosition;

  SpellAction({required this.targetPosition})
    : super(
        type: ActionType.spell,
        name: 'Spell',
        description: 'Spell attack using class spellcasting ability',
        apCost: 25,
        economyType: ActionEconomyType.action,
      );
}

class RangedAction extends GameAction {
  final Vector2 targetPosition;

  RangedAction({required this.targetPosition})
    : super(
        type: ActionType.ranged,
        name: 'Bow Shot',
        description: 'Ranged weapon strike (1d8 + DEX)',
        apCost: 25,
        economyType: ActionEconomyType.action,
      );
}

/// Rapid dash repositioning.
class DashAction extends GameAction {
  final Vector2 targetPosition;

  DashAction({required this.targetPosition})
    : super(
        type: ActionType.dash,
        name: 'Dash',
        description: 'Quick repositioning maneuver',
        apCost: 20,
        economyType: ActionEconomyType.bonusAction,
      );
}

/// Fighter's Second Wind recovery.
class HealAction extends GameAction {
  HealAction()
    : super(
        type: ActionType.heal,
        name: 'Second Wind',
        description: 'Heal 1d10 + Level HP',
        apCost: 30,
        economyType: ActionEconomyType.bonusAction,
      );
}
