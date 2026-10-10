import 'capability_registry.dart';
import 'fixed_units.dart';

/// The operation category of a physical modifier.
enum ModifierKind { add, mul, overrideVal, cap }

/// A deterministic modifier affecting stats or physical capabilities.
///
/// Calculation order (PHYSICS_HANDOFF 3.2):
/// 1. Base value (derived from primary stat formula)
/// 2. Fixed additions (`add`)
/// 3. Multipliers (`mul`): grouped by [sourceGroup], only the largest applies (no stacking)
/// 4. Overrides (`overrideVal`): applied by ascending [priority]
/// 5. Caps / Clamps (`cap`)
class Modifier {
  final String id;
  final ModifierKind kind;
  final Fixed value;
  final Set<Capability> scope;
  final String sourceGroup;
  final int priority;
  final int durationTicks;

  const Modifier({
    required this.id,
    required this.kind,
    required this.value,
    required this.scope,
    this.sourceGroup = 'default',
    this.priority = 100,
    this.durationTicks = 0,
  });

  /// Evaluates an initial [baseValue] for a specific [targetCapability] through
  /// an iterable of [modifiers], strictly obeying scope and evaluation priority.
  static Fixed evaluate({
    required Capability targetCapability,
    required Fixed baseValue,
    required Iterable<Modifier> modifiers,
  }) {
    final inScope = modifiers
        .where((m) => m.scope.contains(targetCapability))
        .toList(growable: false);

    // 1. Base value
    var current = baseValue;

    // 2. Additions: sum all flat additions
    for (final m in inScope) {
      if (m.kind == ModifierKind.add) {
        current = current.add(m.value);
      }
    }

    // 3. Multipliers: grouped by sourceGroup, only highest per group applies
    final groupMaxMul = <String, Fixed>{};
    for (final m in inScope) {
      if (m.kind == ModifierKind.mul) {
        final existing = groupMaxMul[m.sourceGroup];
        if (existing == null || m.value.isGreaterThan(existing)) {
          groupMaxMul[m.sourceGroup] = m.value;
        }
      }
    }
    for (final mul in groupMaxMul.values) {
      current = current.mulFixed(mul);
    }

    // 4. Overrides: applied in ascending priority order (lower priority runs first)
    final overrides =
        inScope.where((m) => m.kind == ModifierKind.overrideVal).toList()
          ..sort((a, b) => a.priority.compareTo(b.priority));
    for (final m in overrides) {
      current = m.value;
    }

    // 5. Caps: apply maximum ceiling
    for (final m in inScope) {
      if (m.kind == ModifierKind.cap && current.isGreaterThan(m.value)) {
        current = m.value;
      }
    }

    return current;
  }
}
