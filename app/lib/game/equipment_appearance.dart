import 'dart:async';
import 'dart:ui' as ui;

import 'package:flame/components.dart';

import '../core/inventory/equipment_slot.dart';
import '../core/inventory/inventory.dart';

class EquipmentAppearance {
  static const renderOrder = [
    EquipmentSlot.neck,
    EquipmentSlot.legs,
    EquipmentSlot.feet,
    EquipmentSlot.hands,
    EquipmentSlot.chest,
    EquipmentSlot.head,
    EquipmentSlot.ring,
    EquipmentSlot.offHand,
    EquipmentSlot.mainHand,
  ];

  Map<EquipmentSlot, List<Sprite>> _frames = {};
  List<EquipmentItem> items = const [];
  int _generation = 0;

  bool get hasWeapon => _frames.containsKey(EquipmentSlot.mainHand);

  List<Sprite> spritesAt(int frame) => [
    for (final slot in renderOrder)
      if (_frames.containsKey(slot)) _frames[slot]![frame],
  ];

  void cancelPending() => _generation++;

  Future<void> applyAtlas(
    List<EquipmentItem> requested,
    Future<ui.Image> Function(String path) load,
  ) => apply(requested, (path) async {
    final image = await load(path);
    if (image.width != 832 || image.height != 64) {
      throw StateError('Invalid equipment atlas $path: expected 832x64.');
    }
    return [
      for (var index = 0; index < 13; index++)
        Sprite(
          image,
          srcPosition: Vector2(index * 64.0, 0),
          srcSize: Vector2.all(64),
        ),
    ];
  });

  Future<void> apply(
    List<EquipmentItem> requested,
    Future<List<Sprite>> Function(String path) load, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final generation = ++_generation;
    final outfit = List<EquipmentItem>.unmodifiable(requested);
    final frames = <EquipmentSlot, List<Sprite>>{};
    final pending = () async {
      for (final item in outfit) {
        final slot = item.equipmentSlot;
        final path = item.fighterLayerPath;
        if (slot == null || path == null || frames.containsKey(slot)) {
          throw ArgumentError('Invalid or duplicate equipment: ${item.id}');
        }
        frames[slot] = await load(path);
        if (frames[slot]!.length != 13) {
          throw StateError('Equipment must have 13 frames: $path');
        }
      }
    }();
    try {
      await pending.timeout(timeout);
    } on TimeoutException {
      if (_generation == generation) cancelPending();
      rethrow;
    }
    if (_generation != generation) {
      throw StateError('Equipment operation was cancelled or superseded.');
    }
    _frames = frames;
    items = outfit;
  }
}
