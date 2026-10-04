import 'dart:io';

import 'metrics.dart';

Map<String, SourceMetrics> measureSources(Directory root) {
  final production = Directory('${root.path}/app/lib');
  if (!production.existsSync())
    throw FileSystemException('Missing production sources', production.path);
  final measured = <String, SourceMetrics>{};
  for (final directory in [
    production,
    Directory('${root.path}/tooling/code_quality/lib'),
    Directory('${root.path}/tooling/code_quality/bin'),
  ]) {
    if (!directory.existsSync()) continue;
    final files =
        directory
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final name = file.path
          .substring(root.path.length + 1)
          .replaceAll('\\', '/');
      measured[name] = measure(file.readAsStringSync(), name);
    }
  }
  return measured;
}
