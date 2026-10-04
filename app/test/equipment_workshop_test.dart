import 'package:builds_and_bosses_flame/core/inventory/equipment_grid.dart';
import 'package:builds_and_bosses_flame/core/inventory/equipment_slot.dart';
import 'package:builds_and_bosses_flame/core/inventory/godot_sample_equipment.dart';
import 'package:builds_and_bosses_flame/core/inventory/inventory.dart';
import 'package:builds_and_bosses_flame/ui/equipment_workshop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const sword = EquipmentItem(
  id: 'test-sword',
  name: 'Test sword',
  role: EquipmentRole.frontline,
  modifiers: {'damage': 2},
  equipmentSlot: EquipmentSlot.mainHand,
);

void main() {
  test('3x3 equipped grid enforces body slots and removes equipment', () {
    final grid = EquipmentGrid();
    expect(EquipmentGrid.rows, 3);
    expect(EquipmentGrid.columns, 3);
    expect(EquipmentGrid.capacity, 9);
    expect(grid.occupiedCount, 0);
    for (var i = 0; i < EquipmentGrid.capacity; i++) {
      expect(grid.itemAt(i), isNull);
    }
    grid.place(3, sword);
    expect(() => grid.place(3, sword), throwsStateError);
    grid.move(3, 3);
    expect(grid.itemAt(3), same(sword));
    expect(() => grid.move(3, 1), throwsArgumentError);
    expect(grid.occupiedCount, 1);
    expect(grid.remove(3), same(sword));
    expect(grid.occupiedCount, 0);
    expect(() => grid.remove(8), throwsStateError);
    expect(() => grid.move(8, 2), throwsStateError);
    expect(() => grid.itemAt(-1), throwsRangeError);
    expect(() => grid.place(9, sword), throwsRangeError);
    grid.place(3, sword);
    expect(() => grid.move(3, 9), throwsRangeError);
    expect(grid.itemAt(3), same(sword));
    final invalid = grid.slots.toList()..[1] = sword;
    expect(() => grid.replaceAll(invalid), throwsArgumentError);
    expect(grid.itemAt(1), isNull);
    expect(grid.itemAt(3), same(sword));
    for (final item in godotSampleEquipmentSets.single.items) {
      for (var slot = 0; slot < EquipmentGrid.capacity; slot++) {
        expect(grid.fits(slot, item), item.equipmentSlot == grid.slotAt(slot));
        if (!grid.fits(slot, item)) {
          expect(() => grid.place(slot, item), throwsArgumentError);
        }
      }
    }
  });

  testWidgets('empty workshop has exactly nine selectable slots', (
    tester,
  ) async {
    final grid = EquipmentGrid();
    await tester.pumpWidget(
      MaterialApp(home: EquipmentWorkshopScreen(grid: grid)),
    );
    final view = tester.widget<GridView>(
      find.byKey(const ValueKey('workshop-grid')),
    );
    final delegate =
        view.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 3);
    for (var i = 0; i < 9; i++) {
      expect(find.byKey(ValueKey('equipment-slot-$i')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('equipment-slot-9')), findsNothing);
    final armory = tester.widget<GridView>(
      find.byKey(const ValueKey('armory-grid')),
    );
    expect(
      (armory.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      3,
    );
    expect(
      (armory.childrenDelegate as SliverChildBuilderDelegate).childCount,
      9,
    );
    await tester.tap(find.byKey(const ValueKey('equipment-slot-8')));
    await tester.pump();
    expect(find.text('Csizma: üres'), findsOneWidget);
    expect(grid.occupiedCount, 0);
  });

  testWidgets('Godot items drag into slots without consuming armory samples', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final grid = EquipmentGrid();
    await tester.pumpWidget(
      MaterialApp(home: EquipmentWorkshopScreen(grid: grid)),
    );
    await tester.pumpAndSettle();
    final items = godotSampleEquipmentSets.single.items;
    const destinations = [1, 4, 3];
    Future<void> drag(Finder source, Finder destination) async {
      final gesture = await tester.startGesture(tester.getCenter(source));
      await gesture.moveBy(const Offset(-10, 0));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(destination));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    }

    for (var i = 0; i < items.length; i++) {
      await drag(
        find.byKey(ValueKey('armory-item-${items[i].id}')),
        find.byKey(ValueKey('equipment-slot-${destinations[i]}')),
      );
      expect(grid.itemAt(destinations[i]), same(items[i]));
      expect(
        find.byKey(ValueKey('armory-item-${items[i].id}')),
        findsOneWidget,
      );
    }
    expect(grid.occupiedCount, 3);
    await drag(
      find.byKey(ValueKey('armory-item-${items[0].id}')),
      find.byKey(const ValueKey('equipment-slot-1')),
    );
    expect(grid.itemAt(1), same(items[0]));
    expect(grid.occupiedCount, 3);
    expect(find.text('Ez a felszereléshely már foglalt.'), findsOneWidget);
    await drag(
      find.byKey(const ValueKey('equipment-slot-1')),
      find.byKey(const ValueKey('equipment-slot-8')),
    );
    expect(grid.itemAt(1), same(items[0]));
    expect(grid.itemAt(8), isNull);
    expect(find.textContaining('nem ide: Csizma'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('set arrows and keyboard cycle sets without changing workshop', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final sets = [
      ...godotSampleEquipmentSets,
      EquipmentSet(
        id: 'test-set',
        name: 'Test set',
        role: EquipmentRole.frontline,
        items: [sword],
        modifiers: {},
      ),
    ];
    final grid = EquipmentGrid();
    await tester.pumpWidget(
      MaterialApp(
        home: EquipmentWorkshopScreen(grid: grid, sets: sets),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('armory-next')));
    await tester.pumpAndSettle();
    expect(find.text('Armory • 2/2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('armory-item-test-sword')));
    await tester.tap(find.byKey(const ValueKey('equipment-slot-3')));
    await tester.pumpAndSettle();
    expect(grid.itemAt(3), same(sword));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Armory • 1/2'), findsOneWidget);
    expect(grid.itemAt(3), same(sword));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('Armory • 2/2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('armory-previous')));
    await tester.pumpAndSettle();
    expect(find.text('Armory • 1/2'), findsOneWidget);
    expect(grid.itemAt(3), same(sword));
  });

  testWidgets('empty and single-set armories disable navigation', (
    tester,
  ) async {
    final grid = EquipmentGrid();
    await tester.pumpWidget(
      MaterialApp(home: EquipmentWorkshopScreen(grid: grid)),
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('armory-next')))
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: EquipmentWorkshopScreen(grid: grid, sets: const []),
      ),
    );
    await tester.pump();
    expect(find.text('Armory • 0/0'), findsOneWidget);
    expect(find.text('Nincs felszerelésset'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow display scrolls grids and can cancel item selection', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final grid = EquipmentGrid();
    await tester.pumpWidget(
      MaterialApp(home: EquipmentWorkshopScreen(grid: grid)),
    );
    await tester.pumpAndSettle();
    final horizontal = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    await tester.drag(horizontal, const Offset(-350, 0));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('armory-item-godot-sample-helmet')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Kijelölés törlése'));
    await tester.tap(find.text('Kijelölés törlése'));
    await tester.pumpAndSettle();
    expect(find.text('Kijelölés törlése'), findsNothing);
    expect(grid.occupiedCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'equipment syncs with character, persists on reopen and unequips',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final grid = EquipmentGrid()..place(3, sword);
      List<EquipmentItem>? applied;
      await tester.pumpWidget(
        MaterialApp(
          home: EquipmentWorkshopScreen(
            grid: grid,
            onEquipmentChanged: (items) async => applied = items,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('equipment-slot-3')));
      await tester.pump();
      expect(find.text('Azonosító: test-sword'), findsOneWidget);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpWidget(
        MaterialApp(
          home: EquipmentWorkshopScreen(
            grid: grid,
            onEquipmentChanged: (items) async => applied = items,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('equipment-slot-3')));
      await tester.pump();
      expect(find.text('Fegyverkéz: Test sword'), findsOneWidget);
      await tester.tap(find.text('Felszerelés levétele'));
      await tester.pumpAndSettle();
      expect(grid.itemAt(3), isNull);
      expect(applied, isEmpty);
      await tester.tap(
        find.byKey(const ValueKey('armory-item-godot-sample-helmet')),
      );
      await tester.tap(find.byKey(const ValueKey('equipment-slot-1')));
      await tester.pumpAndSettle();
      expect(applied!.single.id, 'godot-sample-helmet');
      expect(grid.itemAt(1), same(applied!.single));
    },
  );

  testWidgets('failed character update leaves equipped grid unchanged', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final grid = EquipmentGrid()..place(3, sword);
    await tester.pumpWidget(
      MaterialApp(
        home: EquipmentWorkshopScreen(
          grid: grid,
          onEquipmentChanged: (_) async =>
              throw StateError('Test atlas loading error'),
        ),
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('armory-item-godot-sample-helmet')),
    );
    await tester.tap(find.byKey(const ValueKey('equipment-slot-1')));
    await tester.pumpAndSettle();
    expect(grid.itemAt(1), isNull);
    expect(grid.itemAt(3), same(sword));
    expect(find.textContaining('Test atlas loading error'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
