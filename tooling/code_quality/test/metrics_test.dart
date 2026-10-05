import 'dart:io';

import 'package:builds_and_bosses_quality/metrics.dart';
import 'package:builds_and_bosses_quality/ratchet.dart';
import 'package:builds_and_bosses_quality/gate.dart';
import 'package:builds_and_bosses_quality/sources.dart';
import 'package:test/test.dart';

void main() {
  test(
    'checker production code obeys its own limits without legacy exemptions',
    () {
      final sources = measureSources(Directory.current.parent.parent);
      for (final entry in sources.entries.where(
        (e) => e.key.startsWith('tooling/'),
      )) {
        expect(
          violations(entry.key, entry.value, null),
          isEmpty,
          reason: entry.key,
        );
      }
    },
  );
  test('counts physical lines without a phantom trailing line', () {
    expect(measure('', 'test.dart').lines, 0);
    expect(measure('void a() {}\n', 'test.dart').lines, 1);
    expect(measure('void a() {}\n\n', 'test.dart').lines, 2);
  });
  test('AST ignores fake branches in comments and strings', () {
    final m = measure('''
void a() {
  // if (x) { while (true) {} }
  final text = "if while &&";
}
''', 'test.dart');
    expect(m.symbols['a']!['cyclomatic'], 1);
  });
  test('nested branches, ternaries, catches and boolean operators', () {
    final m = measure('''
int a(bool x, bool y) {
  try {
    if (x && y) {
      while (x) { return y ? 1 : 2; }
    }
  } catch (e) { return 0; }
  return 3;
}
''', 'test.dart');
    expect(m.symbols['a']!['cyclomatic'], 6);
    expect(m.symbols['a']!['nesting'], 3);
    expect(m.symbols['a']!['parameters'], 2);
  });
  test('closures measured separately from their owner', () {
    final m = measure('''
void a() {
  final f = () { if (true) { return; } };
}
''', 'test.dart');
    expect(m.symbols['a']!['cyclomatic'], 1);
    expect(m.symbols['a.closure']!['cyclomatic'], 2);
  });
  test('class, constructor, generic methods, extensions and switches', () {
    final m = measure('''
class A {
  A() {}
  T echo<T>(T value) => value;
  int check(int v) => switch (v) { 0 => 1, _ => 2 };
}
extension B on int { bool test() => this > 0; }
''', 'test.dart');
    expect(
      m.symbols.keys,
      containsAll(['A.constructor:new', 'A.echo', 'B.test']),
    );
    expect(m.symbols['A.check']!['cyclomatic'], 4);
  });
  test('invalid syntax and part bypass fail closed', () {
    expect(() => measure('void {', 'test.dart'), throwsFormatException);
    expect(
      () => measure("part 'other.dart';", 'test.dart'),
      throwsFormatException,
    );
    expect(
      () => measure("part of 'other.dart';", 'test.dart'),
      throwsFormatException,
    );
  });
  test('new files fail at 651 and legacy files cannot grow', () {
    expect(violations('a', SourceMetrics(651), null), isNotEmpty);
    expect(violations('a', SourceMetrics(650), null), isEmpty);
    expect(violations('a', SourceMetrics(916), {'lines': 915}), isNotEmpty);
    expect(violations('a', SourceMetrics(900), {'lines': 915}), isEmpty);
  });
  test(
    'symbol debt cannot increase and another reduction cannot offset it',
    () {
      final old = measure(
        'void a() { if (true) {} }\nvoid b() {}',
        'test.dart',
      );
      final current = measure(
        'void a() { if (true) { if (true) {} } }\nvoid b() {}',
        'test.dart',
      );
      final baseline = old.toJson();
      final symbols = baseline['symbols']! as Map<String, Map<String, int>>;
      symbols['a']!['cyclomatic'] = 16;
      current.symbols['a']!['cyclomatic'] = 17;
      expect(violations('a', current, baseline), isNotEmpty);
    },
  );
  test('body identity carries existing debt across renames', () {
    final body = 'if (true) {} ' * 16;
    final old = measure('void before() { $body }', 'test.dart');
    final current = measure('void after() { $body }', 'test.dart');
    expect(violations('a', current, old.toJson()), isEmpty);
  });
  test('moving a method carries its debt without granting a new exemption', () {
    final body = 'if (true) {} ' * 16;
    final old = measure('void before() { $body }', 'test.dart');
    final current = measure('void after() { $body }', 'moved.dart');
    expect(
      violations('moved', current, null, history: {'old': old.toJson()}),
      isEmpty,
    );
    current.symbols['after']!['cyclomatic'] =
        current.symbols['after']!['cyclomatic']! + 1;
    expect(
      violations('moved', current, null, history: {'old': old.toJson()}),
      isNotEmpty,
    );
  });
  test('conditional import and export dependencies are all measured', () {
    final metrics = measure("""
import 'base.dart' if (dart.library.io) 'native.dart';
export 'base.dart' if (dart.library.html) 'web.dart';
""", 'test.dart');
    expect(
      metrics.imports,
      containsAll(['base.dart', 'native.dart', 'web.dart']),
    );
  });
  test('copying a grandfathered method does not grant its exemption twice', () {
    final body = 'if (true) {} ' * 16;
    final old = measure('void original() { $body }', 'old.dart');
    final copy = measure('void copy() { $body }', 'copy.dart');
    expect(
      checkSources(
        {'old.dart': old, 'copy.dart': copy},
        {'old.dart': old.toJson()},
        {},
        {},
      ),
      isNotEmpty,
    );
    final sameFile = measure(
      'void original() { $body }\nvoid copy() { $body }',
      'old.dart',
    );
    expect(violations('old.dart', sameFile, old.toJson()), isNotEmpty);
  });
}
