import 'dart:convert';
import 'dart:io';

import '../lib/gate.dart';
import '../lib/metrics.dart';
import '../lib/sources.dart';

void main(List<String> args) {
  try {
    run(args);
  } on Exception catch (error) {
    stderr.writeln('QUALITY ERROR: $error');
    exitCode = 1;
  } on StateError catch (error) {
    stderr.writeln('QUALITY ERROR: $error');
    exitCode = 1;
  } on ArgumentError catch (error) {
    stderr.writeln('QUALITY ERROR: $error');
    exitCode = 1;
  }
}

void run(List<String> args) {
  _validateArgs(args);
  final root = args.length >= 3
      ? Directory(args[2])
      : Directory.current.parent.parent;
  final measured = measureSources(root);
  final baselineFile = File('${root.path}/tooling/code_quality/baseline.json');
  _execute(args, root, measured, baselineFile);
}

void _validateArgs(List<String> args) {
  if (args.isEmpty ||
      !['check', 'init', 'report'].contains(args.first) ||
      ![1, 3, 5].contains(args.length) ||
      (args.length >= 3 && args[1] != '--root') ||
      (args.length == 5 && args[3] != '--reference-root')) {
    throw ArgumentError(
      'Usage: check|init|report [--root path [--reference-root path]]',
    );
  }
}

void _execute(
  List<String> args,
  Directory root,
  Map<String, SourceMetrics> measured,
  File baselineFile,
) {
  if (args.first == 'init') {
    if (baselineFile.existsSync())
      throw StateError('Baseline already exists; overwrites forbidden.');
    baselineFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'files': {for (final e in measured.entries) e.key: e.value.toJson()},
      })}\n',
    );
    stdout.writeln(
      'Initialized explicit legacy baseline for ${measured.length} files.',
    );
    return;
  }
  for (final entry in measured.entries) {
    if (args.first == 'report') {
      stdout.writeln(
        '${entry.value.lines}\t${entry.key}\t${entry.value.sourceHash}',
      );
    } else if (entry.value.lines >= 700) {
      stdout.writeln(
        'REVIEW 700: ${entry.key} (${entry.value.lines} lines; capacity ${800 - entry.value.lines}).',
      );
    }
  }
  if (args.first == 'report') return;
  final baseline = readJsonObject(baselineFile);
  if (baseline['version'] != 1 || baseline['files'] is! Map<String, dynamic>) {
    throw const FormatException('Unsupported or malformed baseline');
  }
  final reference = args.length == 5
      ? measureSources(Directory(args[4]))
      : null;
  final errors = checkSources(
    measured,
    baseline['files'] as Map<String, dynamic>,
    reference == null
        ? {}
        : {for (final e in reference.entries) e.key: e.value.toJson()},
    readJsonObject(
      File('${root.path}/tooling/code_quality/capacity_reviews.json'),
    ),
  );
  if (errors.isEmpty) {
    stdout.writeln(
      'Quality gate passed: ${measured.length} production Dart files.',
    );
  } else {
    for (final error in errors) {
      stderr.writeln(error);
    }
    exitCode = 1;
  }
}

Map<String, dynamic> readJsonObject(File file) {
  final value = jsonDecode(file.readAsStringSync());
  if (value is! Map<String, dynamic>)
    throw FormatException('Expected JSON object: ${file.path}');
  return value;
}
