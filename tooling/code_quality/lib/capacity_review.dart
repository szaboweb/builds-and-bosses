import 'metrics.dart';

bool validCapacityReview(
  SourceMetrics current,
  Map<String, dynamic>? previous,
  Map<String, dynamic>? review,
) {
  if (review == null || review['sourceHash'] != current.sourceHash)
    return false;
  for (final field in ['owner', 'reason']) {
    final value = review[field];
    if (value is! String || value.trim().isEmpty) return false;
  }
  final upperBound = review['upperBound'];
  final ceiling = current.lines > 650
      ? (previous?['lines'] as int? ?? 650)
      : 650;
  if (upperBound is! int || upperBound < current.lines || upperBound > ceiling)
    return false;
  return ['extend', 'reuse', 'extract'].contains(review['decision']);
}
