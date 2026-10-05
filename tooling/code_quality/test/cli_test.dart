import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Directory root;
  late File source;
  ProcessResult run(
    String mode,
  ) => Process.runSync(Platform.resolvedExecutable, [
    '--packages=${Directory.current.path}${Platform.pathSeparator}.dart_tool${Platform.pathSeparator}package_config.json',
    'bin${Platform.pathSeparator}check.dart',
    mode,
    '--root',
    root.path,
  ]);
  setUp(() {
    root = Directory.systemTemp.createTempSync('bb-quality-test-');
    Directory('${root.path}/app/lib').createSync(recursive: true);
    Directory('${root.path}/tooling/code_quality').createSync(recursive: true);
    File(
      '${root.path}/tooling/code_quality/capacity_reviews.json',
    ).writeAsStringSync('{}');
    source = File('${root.path}/app/lib/sample.dart')
      ..writeAsStringSync('void a() {}\n');
    expect(run('init').exitCode, 0);
  });
  tearDown(() => root.deleteSync(recursive: true));
  test(
    'CLI succeeds, refuses baseline overwrite and rejects size regression',
    () {
      expect(run('check').exitCode, 0);
      expect(run('init').exitCode, isNonZero);
      source.writeAsStringSync('void a() {}\n${'// comment\n' * 650}');
      final result = run('check');
      expect(result.exitCode, isNonZero);
      expect(result.stderr, contains('651 lines'));
    },
  );
  test('new relative core/game dependency and import cycles fail', () {
    Directory('${root.path}/app/lib/core').createSync();
    Directory('${root.path}/app/lib/game').createSync();
    File(
      '${root.path}/app/lib/core/rule.dart',
    ).writeAsStringSync("import '../game/runtime.dart';\n");
    File(
      '${root.path}/app/lib/game/runtime.dart',
    ).writeAsStringSync("import '../core/rule.dart';\n");
    final result = run('check');
    expect(result.exitCode, isNonZero);
    expect(result.stderr, contains('forbidden core dependency'));
    expect(result.stderr, contains('Import cycle'));
  });
  test('package-qualified core dependencies are not a boundary bypass', () {
    Directory('${root.path}/app/lib/core').createSync();
    File('${root.path}/app/lib/core/rule.dart').writeAsStringSync(
      "import 'package:builds_and_bosses_flame/game/runtime.dart';\n",
    );
    final result = run('check');
    expect(result.exitCode, isNonZero);
    expect(result.stderr, contains('forbidden core dependency'));
  });
  test('merge-base improvement cannot regress under an older debt ceiling', () {
    final reference = Directory('${root.path}/reference/app/lib')
      ..createSync(recursive: true);
    File(
      '${reference.path}/sample.dart',
    ).writeAsStringSync('void a() {}\n${'// comment\n' * 819}');
    source.writeAsStringSync('void a() {}\n${'// comment\n' * 849}');
    final baselineFile = File(
      '${root.path}/tooling/code_quality/baseline.json',
    );
    final baseline =
        jsonDecode(baselineFile.readAsStringSync()) as Map<String, dynamic>;
    final files = baseline['files'] as Map<String, dynamic>;
    (files['app/lib/sample.dart'] as Map<String, dynamic>)['lines'] = 900;
    baselineFile.writeAsStringSync(jsonEncode(baseline));
    final result = Process.runSync(Platform.resolvedExecutable, [
      '--packages=${Directory.current.path}${Platform.pathSeparator}.dart_tool${Platform.pathSeparator}package_config.json',
      'bin${Platform.pathSeparator}check.dart',
      'check',
      '--root',
      root.path,
      '--reference-root',
      '${root.path}/reference',
    ]);
    expect(result.exitCode, isNonZero);
    expect(result.stderr, contains('Merge-base regression:'));
    expect(result.stderr, contains('850 lines exceeds 820'));
  });
  test('unchanged file rename preserves baseline', () {
    source.renameSync('${root.path}/app/lib/renamed.dart');
    expect(run('check').exitCode, 0);
  });
  test('changed 550-line file requires hash-bound review', () {
    source.writeAsStringSync('void a() {}\n${'// comment\n' * 549}');
    final result = run('check');
    expect(result.exitCode, isNonZero);
    expect(result.stderr, contains('requires hash-bound capacity review'));
    final report = run('report');
    expect(report.stdout, contains('550'));
    // Source hash is calculated by the same measured baseline format.
    final original = File('${root.path}/tooling/code_quality/baseline.json');
    original.deleteSync();
    expect(run('init').exitCode, 0);
    final baseline =
        jsonDecode(original.readAsStringSync()) as Map<String, dynamic>;
    final files = baseline['files'] as Map<String, dynamic>;
    final metrics = files['app/lib/sample.dart'] as Map<String, dynamic>;
    File(
      '${root.path}/tooling/code_quality/capacity_reviews.json',
    ).writeAsStringSync(
      jsonEncode({
        'app/lib/sample.dart': {
          'sourceHash': metrics['sourceHash'],
          'owner': 'sample fixture',
          'upperBound': 580,
          'reason': 'test coherent ownership',
          'decision': 'extend',
        },
      }),
    );
    // Restore the initial, small baseline: approved review enables current growth.
    metrics['sourceHash'] = 'previous';
    metrics['lines'] = 1;
    original.writeAsStringSync(jsonEncode(baseline));
    expect(run('check').exitCode, 0);
  });
  test('malformed sources and unsupported baselines fail', () {
    source.writeAsStringSync('void {');
    expect(run('check').exitCode, isNonZero);
    source.writeAsStringSync('void a() {}');
    File(
      '${root.path}/tooling/code_quality/baseline.json',
    ).writeAsStringSync('{"version":999}');
    expect(run('check').exitCode, isNonZero);
  });
}
