import 'dart:async';
import 'dart:convert';

import 'package:builds_and_bosses_flame/core/inventory/godot_sample_equipment.dart';
import 'package:builds_and_bosses_flame/core/inventory/equipment_grid.dart';
import 'package:builds_and_bosses_flame/ui/equipment_workshop_screen.dart';
import 'package:builds_and_bosses_flame/core/platform/platform_services.dart';
import 'package:builds_and_bosses_flame/game/combat_completion.dart';
import 'package:builds_and_bosses_flame/game/equipment_appearance.dart';
import 'package:builds_and_bosses_flame/game/components/wizard_animation_controller.dart';
import 'package:builds_and_bosses_flame/game/tactical_game.dart';
import 'package:builds_and_bosses_flame/core/actions/game_action.dart';
import 'package:builds_and_bosses_flame/platform/local_platform_services.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FailingPlatform implements PlatformServices {
  bool hang = false;
  int achievements = 0;
  @override
  bool get isAvailable => true;
  @override
  Future<bool> syncCombatStatistics(CombatStatistics statistics) =>
      hang ? Completer<bool>().future : Future.error(StateError('save failed'));
  @override
  Future<void> unlockAchievement(String id) async {
    achievements++;
  }

  @override
  Future<void> saveCloudData(String key, Map<String, dynamic> data) async {}
  @override
  Future<Map<String, dynamic>?> loadCloudData(String key) async => null;
  @override
  Future<List<CombatStatistics>> loadPendingCombatStatistics() async => [];
}

class FakeSprite extends Fake implements Sprite {}

class RejectingPreferences extends Fake implements SharedPreferences {
  @override
  Future<bool> setString(String key, String value) async => false;
  @override
  Future<bool> setStringList(String key, List<String> value) async => false;
  @override
  List<String>? getStringList(String key) => [];
}

class ManifestBundle extends CachingAssetBundle {
  final Future<String> manifest;
  ManifestBundle(this.manifest);
  @override
  Future<String> loadString(String key, {bool cache = true}) => manifest;
  @override
  Future<ByteData> load(String key) => rootBundle.load(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('equipment timeout never commits a late result', () async {
    final appearance = EquipmentAppearance();
    final pending = Completer<List<Sprite>>();
    final operation = appearance.apply(
      [godotSampleEquipmentSets.single.items.first],
      (_) => pending.future,
      timeout: const Duration(milliseconds: 1),
    );
    await expectLater(operation, throwsA(isA<TimeoutException>()));
    pending.complete(List.generate(13, (_) => FakeSprite()));
    await Future<void>.delayed(Duration.zero);
    expect(appearance.items, isEmpty);
  });
  test('equipment cancelled operation does not commit', () async {
    final appearance = EquipmentAppearance();
    final pending = Completer<List<Sprite>>();
    final operation = appearance.apply([
      godotSampleEquipmentSets.single.items.first,
    ], (_) => pending.future);
    appearance.cancelPending();
    pending.complete(List.generate(13, (_) => FakeSprite()));
    await expectLater(operation, throwsStateError);
    expect(appearance.items, isEmpty);
  });
  test(
    'platform failures and timeouts are reported without blocking achievement',
    () async {
      final platform = FailingPlatform();
      final completion = CombatCompletion(
        platform,
        timeout: const Duration(milliseconds: 1),
      );
      final statistics = CombatStatistics(
        runId: '1',
        completedAt: DateTime(2026),
        heroName: 'fighter',
        bossId: 'golem',
        outcome: 'victory',
        durationMs: 1,
      );
      await completion.record(statistics);
      expect(completion.error.value, contains('save failed'));
      expect(platform.achievements, 1);
      platform.hang = true;
      await completion.record(statistics);
      expect(completion.error.value, contains('TimeoutException'));
      completion.dispose();
    },
  );
  test(
    'local storage round-trip, malformed data and unavailable store',
    () async {
      SharedPreferences.setMockInitialValues({});
      final services = LocalPlatformServices();
      await services.saveCloudData('hero', {'name': 'fighter'});
      expect(await services.loadCloudData('hero'), {'name': 'fighter'});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_cache_bad', '{');
      await expectLater(services.loadCloudData('bad'), throwsFormatException);
      final hanging = LocalPlatformServices(
        preferences: () => Completer<SharedPreferences>().future,
        timeout: const Duration(milliseconds: 1),
      );
      await expectLater(
        hanging.saveCloudData('hero', {}),
        throwsA(isA<TimeoutException>()),
      );
    },
  );
  test('local storage rejected writes are not success-shaped', () async {
    final services = LocalPlatformServices(
      preferences: () async => RejectingPreferences(),
    );
    await expectLater(services.saveCloudData('hero', {}), throwsStateError);
    final stats = CombatStatistics(
      runId: '1',
      completedAt: DateTime(2026),
      heroName: 'fighter',
      bossId: 'golem',
      outcome: 'victory',
      durationMs: 1,
    );
    await expectLater(services.syncCombatStatistics(stats), throwsStateError);
    await expectLater(services.syncCombatStatistics(stats), throwsStateError);
  });
  test('overlapping statistics writes retain both runs', () async {
    SharedPreferences.setMockInitialValues({});
    final services = LocalPlatformServices();
    final stats = CombatStatistics(
      runId: '1',
      completedAt: DateTime(2026),
      heroName: 'fighter',
      bossId: 'golem',
      outcome: 'victory',
      durationMs: 1,
    );
    await Future.wait([
      services.syncCombatStatistics(stats),
      services.syncCombatStatistics(stats),
    ]);
    expect(await services.loadPendingCombatStatistics(), hasLength(2));
  });
  testWidgets('wizard animation loads actual assets and retains live image', (
    tester,
  ) async {
    final wizard = WizardAnimationController();
    await tester.runAsync(wizard.loadManifest);
    expect(wizard.animations, isNotEmpty);
    expect(wizard.size, Vector2.all(32));
    wizard.onRemove();
  });
  testWidgets('malformed wizard manifest retains previous animation', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final wizard = WizardAnimationController();
      await wizard.loadManifest();
      final previous = wizard.animations;
      final source = await rootBundle.loadString(
        'assets/images/characters/wizard_13/walk13_sprite_manifest.json',
      );
      final manifest = jsonDecode(source) as Map<String, dynamic>;
      manifest['cell_w'] = 0;
      await expectLater(
        wizard.loadManifest(
          bundle: ManifestBundle(Future.value(jsonEncode(manifest))),
        ),
        throwsFormatException,
      );
      expect(wizard.animations, equals(previous));
      expect(
        await wizard.animations!.values.first.frames.first.sprite.image
            .toByteData(),
        isNotNull,
      );
      wizard.onRemove();
    });
  });
  testWidgets('wizard removed during loading cannot resurrect decoded image', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final wizard = WizardAnimationController();
      final pending = Completer<String>();
      final loading = wizard.loadManifest(
        bundle: ManifestBundle(pending.future),
      );
      wizard.onRemove();
      pending.complete(
        await rootBundle.loadString(
          'assets/images/characters/wizard_13/walk13_sprite_manifest.json',
        ),
      );
      await expectLater(loading, throwsStateError);
      expect(wizard.animations, isEmpty);
    });
  });
  testWidgets('workshop timeout unlocks retry and ignores late result', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final grid = EquipmentGrid();
    final pending = Completer<void>();
    var attempts = 0;
    var cancellations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: EquipmentWorkshopScreen(
          grid: grid,
          operationTimeout: const Duration(seconds: 1),
          onEquipmentChanged: (_) {
            attempts++;
            return attempts == 1 ? pending.future : Future.value();
          },
          onCancelEquipmentUpdate: () => cancellations++,
        ),
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('armory-item-godot-sample-helmet')),
    );
    await tester.tap(find.byKey(const ValueKey('equipment-slot-1')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(grid.occupiedCount, 0);
    expect(cancellations, 1);
    await tester.tap(find.byKey(const ValueKey('equipment-slot-1')));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(grid.occupiedCount, 1);
    pending.complete();
    await tester.pump();
    expect(grid.occupiedCount, 1);
  });
  testWidgets(
    'closing workshop cancels loading without committing after dispose',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final grid = EquipmentGrid();
      final pending = Completer<void>();
      var cancellations = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: EquipmentWorkshopScreen(
            grid: grid,
            onEquipmentChanged: (_) => pending.future,
            onCancelEquipmentUpdate: () => cancellations++,
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('armory-item-godot-sample-helmet')),
      );
      await tester.tap(find.byKey(const ValueKey('equipment-slot-1')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete();
      await tester.pump();
      expect(cancellations, 1);
      expect(grid.occupiedCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('restart cancels pending player plan and stale callback', (
    tester,
  ) async {
    final game = TacticalModeGame();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GameWidget(game: game)),
      ),
    );
    await tester.runAsync(() => game.ready());
    var callbacks = 0;
    game.player.executePlan([
      MoveAction(targetPosition: Vector2(1000, 500)),
    ], () => callbacks++);
    game.restartCombat();
    expect(game.player.isExecutingPlan, isFalse);
    game.player.update(10);
    expect(callbacks, 0);
    expect(game.currentPhase, GamePhase.realtime);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
