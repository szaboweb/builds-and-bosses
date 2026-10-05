import 'package:builds_and_bosses_flame/ui/widgets/rpg_stat_badge_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RpgStatBadgeWidget', () {
    testWidgets('renders basic badge with text and custom colors', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RpgStatBadgeWidget(
              label: 'Test Badge',
              textColor: Colors.amber,
              icon: Icons.shield,
            ),
          ),
        ),
      );

      expect(find.text('Test Badge'), findsOneWidget);
      expect(find.byIcon(Icons.shield), findsOneWidget);
    });

    testWidgets('renders AC factory correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: RpgStatBadgeWidget.ac(18))),
      );

      expect(find.text('AC 18'), findsOneWidget);
    });

    testWidgets('renders AP factory correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: RpgStatBadgeWidget.ap(150))),
      );

      expect(find.text('150 AP'), findsOneWidget);
    });

    testWidgets('renders attribute factory correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RpgStatBadgeWidget.attribute(
              name: 'STR',
              score: 20,
              extra: '138px',
              color: const Color(0xFF00E5FF),
            ),
          ),
        ),
      );

      expect(find.text('STR 20 (138px)'), findsOneWidget);
    });
  });
}
