import 'dart:async';
import 'dart:ui' as ui;

import 'package:flame/components.dart';

import '../../core/combat/combat_logger.dart';
import '../../core/inventory/inventory.dart';
import '../equipment_appearance.dart';
import 'fighter_body_profile.dart';

/// Owns sprite-sheet loading/validation, locomotion-driven frame selection
/// and equipment-layer sync for the player's fighter body. Extracted from
/// `PlayerComponent` per docs/ARCHITECTURE.md's "Fighter visual renderer"
/// responsibility contract: atlas validation, pose/frame selection and
/// equipment layers, independent of movement/combat rules.
class FighterAnimator {
  static const List<int> _idleFrames = [0];
  static const List<int> _walkFrames = [1, 2];
  static const List<int> _runFrames = [3, 4];
  static const List<int> _fighterWalkFrames = [
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
  ];
  // Pixels covered by one full cycle, used to sync steps to real speed.
  static const double _walkStrideLength = 26;
  static const double _runStrideLength = 44;
  static const double _fighterStrideLength = 96;

  FighterBodyProfile _profile = FighterBodyProfile.godotFighter;
  List<Sprite> _frames = const [];
  double _animationPhase = 0.0;
  final EquipmentAppearance _appearance = EquipmentAppearance();

  Sprite? sprite;
  FighterBodyProfile get profile => _profile;
  bool get hasWeapon => _appearance.hasWeapon;
  List<EquipmentItem> get equippedItems => _appearance.items;

  List<Sprite> get equipmentSprites {
    if (!_profile.usesEquipmentLayers || sprite == null) return const [];
    final frame = (sprite!.srcPosition.x / _profile.frameSize).round();
    return _appearance.spritesAt(frame);
  }

  void cancelEquipmentUpdate() => _appearance.cancelPending();

  Future<void> setEquipment(
    List<EquipmentItem> items,
    Future<ui.Image> Function(String path) load,
  ) {
    if (items.isNotEmpty && (!_profile.usesEquipmentLayers || sprite == null)) {
      throw StateError(
        'A mintafelszerelés csak a Godot fighterhez használható.',
      );
    }
    return _appearance.applyAtlas(items, load);
  }

  /// Rebuilds the frame list for [sheetPath], resolving its body profile.
  Future<bool> reload(
    String sheetPath,
    Future<ui.Image> Function(String path) load,
  ) async {
    try {
      final profile = FighterBodyProfile.forSheetPath(sheetPath);
      final image = await load(sheetPath);
      final frameCount = (image.width / profile.frameSize).floor();
      if (image.height != profile.frameSize ||
          image.width % profile.frameSize != 0 ||
          frameCount < profile.minFrameCount) {
        throw StateError(
          'Invalid character atlas $sheetPath: '
          '${image.width}x${image.height}, expected a row of '
          '${profile.frameSize.toInt()}px cells.',
        );
      }
      _profile = profile;
      _animationPhase = 0;
      _frames = [
        for (var index = 0; index < frameCount; index++)
          Sprite(
            image,
            srcPosition: Vector2(index * profile.frameSize, 0),
            srcSize: Vector2.all(profile.frameSize),
          ),
      ];
      sprite = _frames.isEmpty ? null : _frames.first;
      return true;
    } catch (error) {
      CombatLogger.instance.logWarning(
        'ANIMATION',
        'Unable to load character atlas $sheetPath: $error. '
            'Retaining existing appearance.',
      );
      return false;
    }
  }

  /// Picks idle/walk/run from the body's own speed and advances the cycle so
  /// a full stride covers the body's stride length, which keeps feet from
  /// sliding.
  void updateLocomotionFrame({
    required double dt,
    required double speed,
    required double moveSpeed,
    required bool isOnGround,
  }) {
    if (_frames.isEmpty) return;
    final selection = _selectCycle(
      speed: speed,
      moveSpeed: moveSpeed,
      isOnGround: isOnGround,
    );
    if (selection.strideLength <= 0) {
      _animationPhase = 0;
    } else {
      _animationPhase +=
          speed * dt / selection.strideLength * selection.cycle.length;
      _animationPhase %= selection.cycle.length;
    }
    final frameIndex =
        selection.cycle[_animationPhase.floor() % selection.cycle.length];
    if (frameIndex < _frames.length) {
      sprite = _frames[frameIndex];
    }
  }

  /// Chooses the active frame cycle and its stride length, as separate,
  /// early-returning cases rather than a nested if/else chain (kept flat for
  /// the project's cognitive-complexity gate).
  ({List<int> cycle, double strideLength}) _selectCycle({
    required double speed,
    required double moveSpeed,
    required bool isOnGround,
  }) {
    if (_profile.usesEquipmentLayers) {
      return _fighterCycle(speed: speed, isOnGround: isOnGround);
    }
    if (!isOnGround) {
      return (cycle: _runFrames, strideLength: 0.0);
    }
    if (speed < 8) {
      return (cycle: _idleFrames, strideLength: 0.0);
    }
    if (speed <= moveSpeed * 1.2) {
      return (cycle: _walkFrames, strideLength: _walkStrideLength);
    }
    return (cycle: _runFrames, strideLength: _runStrideLength);
  }

  /// Jump/fall/flight clips are not authored yet; hold a stride in the air.
  ({List<int> cycle, double strideLength}) _fighterCycle({
    required double speed,
    required bool isOnGround,
  }) {
    if (!isOnGround) {
      return (cycle: const [4], strideLength: 0.0);
    }
    if (speed < 8) {
      return (cycle: _idleFrames, strideLength: 0.0);
    }
    return (cycle: _fighterWalkFrames, strideLength: _fighterStrideLength);
  }
}
