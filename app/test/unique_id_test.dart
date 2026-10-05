import 'package:flutter_test/flutter_test.dart';

import 'package:builds_and_bosses_flame/core/utils/unique_id.dart';

void main() {
  group('UniqueId', () {
    setUp(() {
      UniqueId.resetForTesting();
    });

    test('generates identifiers with custom prefix', () {
      final id = UniqueId.next('plat');
      expect(id.startsWith('plat_'), isTrue);
    });

    test('generates identifiers with default prefix', () {
      final id = UniqueId.next();
      expect(id.startsWith('id_'), isTrue);
    });

    test('guarantees unique IDs even in rapid tight loops', () {
      final generated = <String>{};
      const count = 1000;

      for (var i = 0; i < count; i++) {
        final id = UniqueId.next('elem');
        expect(
          generated.add(id),
          isTrue,
          reason: 'Duplicate ID encountered: $id',
        );
      }

      expect(generated.length, count);
    });

    test('resetForTesting resets the monotonic counter', () {
      UniqueId.next('test');
      UniqueId.resetForTesting();
      final id = UniqueId.next('test');
      expect(id.endsWith('_1'), isTrue);
    });
  });
}
