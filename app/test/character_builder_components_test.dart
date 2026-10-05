import 'package:builds_and_bosses_flame/core/dnd/character_progression.dart';
import 'package:builds_and_bosses_flame/core/dnd/character_stats.dart';
import 'package:builds_and_bosses_flame/ui/character_builder/attribute_stepper_widget.dart';
import 'package:builds_and_bosses_flame/ui/character_builder/character_preview_card.dart';
import 'package:builds_and_bosses_flame/ui/character_builder/level_progression_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LevelProgressionCard', () {
    testWidgets('renders level, ASI status, and triggers onLevelChanged', (
      tester,
    ) async {
      int selectedLevel = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return LevelProgressionCard(
                  currentLevel: selectedLevel,
                  onLevelChanged: (level) {
                    setState(() {
                      selectedLevel = level;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('SZINT 1'), findsOneWidget);
      expect(find.text('ASI Pontok: +0'), findsOneWidget);

      // Tap + button to go to level 2
      final incButton = find.byIcon(Icons.add_circle);
      await tester.tap(incButton);
      await tester.pumpAndSettle();

      expect(selectedLevel, equals(2));
      expect(find.text('SZINT 2'), findsOneWidget);

      // Tap 20 MAX quick chip
      final maxChip = find.text('20 MAX');
      expect(maxChip, findsOneWidget);
      await tester.tap(maxChip);
      await tester.pumpAndSettle();

      expect(selectedLevel, equals(20));
      expect(find.text('SZINT 20'), findsOneWidget);
      expect(find.text('ASI Pontok: +14'), findsOneWidget);
    });
  });

  group('AttributeStepperWidget', () {
    testWidgets('renders label, score and invokes callbacks', (tester) async {
      var incremented = false;
      var decremented = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttributeStepperWidget(
              attributeKey: 'STR',
              label: 'STR (Erő)',
              effectDescription: 'Ugrásmagasság, közelharci sebzés',
              state: AttributeStepperState(
                score: 16,
                canIncrement: true,
                canDecrement: true,
                onIncrement: () => incremented = true,
                onDecrement: () => decremented = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('STR (Erő)'), findsOneWidget);
      expect(find.text('16'), findsOneWidget);
      expect(find.text('+3'), findsOneWidget);
      expect(find.text('Ugrásmagasság, közelharci sebzés'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      expect(incremented, isTrue);

      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      expect(decremented, isTrue);
    });
  });

  group('CharacterPreviewCard', () {
    testWidgets('renders preview stats and platform clearance at level 1', (
      tester,
    ) async {
      final stats = CharacterStats(
        name: 'Hero',
        level: 1,
        strength: 10,
        dexterity: 10,
        constitution: 10,
        intelligence: 10,
        wisdom: 10,
        charisma: 10,
        maxHp: 12,
        currentHp: 12,
        armorClass: 16,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: CharacterPreviewCard(preview: stats, heroLevel: 1),
            ),
          ),
        ),
      );

      expect(find.text('ÉLŐ ELŐNÉZET • STAT-DRIVEN EFFECT'), findsOneWidget);
      expect(find.text('Futási Sebesség (DEX)'), findsOneWidget);
      expect(find.text('180 px/s'), findsOneWidget);
      expect(find.text('12 HP  •  AC 16'), findsOneWidget);
      expect(find.text('100 AP Pool'), findsOneWidget);
      expect(find.text('+2 to Hit'), findsOneWidget);

      // Low jump warning
      expect(
        find.text('⚠ Alacsony ugrás: nem éri el közvetlenül a kőplatformokat!'),
        findsOneWidget,
      );
      // Level 20 summary is not shown
      expect(find.text('20. SZINTŰ HATÁS ELEMZÉS:'), findsNothing);
    });

    testWidgets('renders Level 20 summary card with HP and AP impacts', (
      tester,
    ) async {
      final stats = CharacterStats(
        name: 'Hero',
        level: 20,
        strength: 20,
        dexterity: 20,
        constitution: 20,
        intelligence: 10,
        wisdom: 10,
        charisma: 10,
        maxHp: 224,
        currentHp: 224,
        armorClass: 18,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 700,
              child: CharacterPreviewCard(
                preview: stats,
                heroLevel: CharacterProgression.maxLevel,
              ),
            ),
          ),
        ),
      );

      expect(find.text('20. SZINTŰ HATÁS ELEMZÉS:'), findsOneWidget);
      expect(find.textContaining('LEGNAGYOBB HATÁS'), findsOneWidget);
      expect(find.textContaining('+1500%'), findsOneWidget);
      expect(find.textContaining('Dupla akciókapacitás'), findsOneWidget);
      expect(
        find.text('★ Akrobatikus Ugró: könnyen eléri a magaslati hidat!'),
        findsOneWidget,
      );
    });
  });
}
