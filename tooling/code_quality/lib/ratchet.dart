import 'metrics.dart';

const limits = {
  'lines': 80,
  'cyclomatic': 15,
  'cognitive': 20,
  'nesting': 4,
  'parameters': 7,
};

List<String> violations(
  String file,
  SourceMetrics current,
  Map<String, dynamic>? baseline, {
  Map<String, dynamic> history = const {},
}) {
  final errors = <String>[];
  final oldLines = baseline?['lines'] as int? ?? 0;
  final ceiling = oldLines > 800 ? oldLines : 800;
  if (current.lines > ceiling) {
    errors.add('$file: ${current.lines} lines exceeds $ceiling');
  }
  final oldSymbols = baseline?['symbols'] as Map<String, dynamic>? ?? {};
  final claimed = oldSymbols.keys.where(current.symbols.containsKey).toSet();
  for (final entry in current.symbols.entries) {
    final old =
        _symbolBaseline(
          entry.key,
          current.fingerprints[entry.key],
          baseline,
          claimed,
        ) ??
        _movedSymbol(current.fingerprints[entry.key], history);
    for (final metric in limits.entries) {
      final previous = old?[metric.key] as int? ?? 0;
      final cap = previous > metric.value ? previous : metric.value;
      if (entry.value[metric.key]! > cap) {
        errors.add(
          '$file:${entry.key}: ${metric.key} ${entry.value[metric.key]} exceeds $cap',
        );
      }
    }
  }
  return errors;
}

Map<String, dynamic>? _symbolBaseline(
  String name,
  String? fingerprint,
  Map<String, dynamic>? baseline,
  Set<String> claimed,
) {
  final symbols = baseline?['symbols'] as Map<String, dynamic>? ?? {};
  final sameName = symbols[name] as Map<String, dynamic>?;
  if (sameName != null) return sameName;
  final hashes = baseline?['fingerprints'] as Map<String, dynamic>? ?? {};
  final matching = hashes.entries
      .where(
        (entry) => entry.value == fingerprint && !claimed.contains(entry.key),
      )
      .toList();
  if (matching.length != 1) return null;
  claimed.add(matching.single.key);
  return symbols[matching.single.key] as Map<String, dynamic>?;
}

Map<String, dynamic>? _movedSymbol(
  String? fingerprint,
  Map<String, dynamic> history,
) {
  final candidates = <Map<String, dynamic>>[];
  for (final value in history.values) {
    final file = value as Map<String, dynamic>;
    final hashes = file['fingerprints'] as Map<String, dynamic>;
    final symbols = file['symbols'] as Map<String, dynamic>;
    for (final entry in hashes.entries) {
      if (entry.value == fingerprint) {
        candidates.add(symbols[entry.key] as Map<String, dynamic>);
      }
    }
  }
  return candidates.length == 1 ? candidates.single : null;
}
