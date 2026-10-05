import 'package:builds_and_bosses_quality/metrics.dart';
import 'package:builds_and_bosses_quality/naming.dart';
import 'package:test/test.dart';

void main() {
  test(
    'valid snake_case file and lowerCamelCase functions pass naming checks',
    () {
      final m = SourceMetrics(10);
      m.symbols['MyClass.updatePhysics'] = {};
      m.symbols['MyClass._resolveLandings'] = {};
      m.symbols['MyClass.constructor:new'] = {};
      m.symbols['MyClass.constructor:fromData'] = {};

      final violations = namingViolations({
        'app/lib/game/components/hero_component.dart': m,
      });
      expect(violations, isEmpty);
    },
  );

  test('non-snake_case file name is rejected', () {
    final m = SourceMetrics(10);
    final violations = namingViolations({'app/lib/game/heroComponent.dart': m});
    expect(violations, hasLength(1));
    expect(violations.single, contains('must use lowercase snake_case'));
  });

  test('UI directory enforces layer suffix', () {
    final m = SourceMetrics(10);
    final valid = namingViolations({'app/lib/ui/combat_hud.dart': m});
    expect(valid, isEmpty);

    final invalid = namingViolations({'app/lib/ui/combat_panel.dart': m});
    expect(invalid, hasLength(1));
    expect(
      invalid.single,
      contains('must end with one of: _overlay.dart, _screen.dart'),
    );
  });

  test('game components directory enforces layer suffix', () {
    final m = SourceMetrics(10);
    final valid = namingViolations({
      'app/lib/game/components/boss_component.dart': m,
    });
    expect(valid, isEmpty);

    final invalid = namingViolations({
      'app/lib/game/components/boss_helper.dart': m,
    });
    expect(invalid, hasLength(1));
    expect(
      invalid.single,
      contains('must end with one of: _component.dart, _controller.dart'),
    );
  });

  test('non-lowerCamelCase function and method names are rejected', () {
    final m = SourceMetrics(10);
    m.symbols['MyClass.snake_case_method'] = {};
    m.symbols['MyClass.PascalCaseMethod'] = {};
    m.symbols['MyClass.constructor:Invalid_Constructor'] = {};

    final violations = namingViolations({'app/lib/core/sample.dart': m});
    expect(violations, hasLength(3));
    expect(
      violations.any(
        (v) => v.contains('snake_case_method') && v.contains('lowerCamelCase'),
      ),
      isTrue,
    );
    expect(
      violations.any(
        (v) => v.contains('PascalCaseMethod') && v.contains('lowerCamelCase'),
      ),
      isTrue,
    );
    expect(
      violations.any(
        (v) =>
            v.contains('Invalid_Constructor') && v.contains('lowerCamelCase'),
      ),
      isTrue,
    );
  });
}
