import 'capacity_review.dart';
import 'dependencies.dart';
import 'metrics.dart';
import 'naming.dart';
import 'ratchet.dart';

Map<String, dynamic>? _previous(
  String name,
  SourceMetrics current,
  Map<String, dynamic> old,
  Map<String, SourceMetrics> measured,
) {
  final sameName = old[name] as Map<String, dynamic>?;
  if (sameName != null) return sameName;
  if (measured.values
          .where((source) => source.sourceHash == current.sourceHash)
          .length !=
      1)
    return null;
  final matches = old.values
      .cast<Map<String, dynamic>>()
      .where((value) => value['sourceHash'] == current.sourceHash)
      .toList();
  return matches.length == 1 ? matches.single : null;
}

Map<String, dynamic> _movedHistory(
  Map<String, dynamic> old,
  Map<String, SourceMetrics> measured,
) {
  final counts = <String, int>{};
  for (final source in measured.values) {
    for (final hash in source.fingerprints.values) {
      counts.update(hash, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  return {
    for (final entry in old.entries)
      if (!measured.containsKey(entry.key))
        entry.key: {
          ...entry.value as Map<String, dynamic>,
          'fingerprints': {
            for (final e
                in ((entry.value as Map<String, dynamic>)['fingerprints']
                        as Map<String, dynamic>)
                    .entries)
              if (counts[e.value] == 1) e.key: e.value,
          },
        },
  };
}

List<String> checkSources(
  Map<String, SourceMetrics> measured,
  Map<String, dynamic> baseline,
  Map<String, dynamic> reference,
  Map<String, dynamic> reviews,
) {
  final errors = <String>[];
  final movedBaseline = _movedHistory(baseline, measured);
  final movedReference = _movedHistory(reference, measured);
  for (final entry in measured.entries) {
    final before = _previous(entry.key, entry.value, baseline, measured);
    errors.addAll(
      violations(entry.key, entry.value, before, history: movedBaseline),
    );
    final previous = reference.isEmpty
        ? before
        : _previous(entry.key, entry.value, reference, measured);
    if (reference.isNotEmpty) {
      errors.addAll(
        violations(
          entry.key,
          entry.value,
          previous,
          history: movedReference,
        ).map((error) => 'Merge-base regression: $error'),
      );
    }
    if (entry.value.lines >= 550 &&
        entry.value.sourceHash != previous?['sourceHash'] &&
        !validCapacityReview(
          entry.value,
          before,
          reviews[entry.key] as Map<String, dynamic>?,
        )) {
      errors.add(
        '${entry.key}: changed >=550 file requires hash-bound capacity review',
      );
    }
  }
  errors.addAll(dependencyViolations(measured));
  errors.addAll(namingViolations(measured));
  return errors;
}
