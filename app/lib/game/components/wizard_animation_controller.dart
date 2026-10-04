import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/services.dart';

enum WizardAnimationState {
  idleRight,
  walkRight,
  runRight,
  turn,
  runLeft,
  walkLeft,
  idleLeft,
  showcaseLoop,
}

class WizardAnimationController
    extends SpriteAnimationGroupComponent<WizardAnimationState> {
  ui.Image? _image;
  int _loadGeneration = 0;

  WizardAnimationController()
    : super(
        size: Vector2.all(32),
        animations: const {},
        current: WizardAnimationState.idleRight,
      );

  static const _sheetPath =
      'assets/images/characters/wizard_13/walk13_rendered.png';
  static const _manifestPath =
      'assets/images/characters/wizard_13/walk13_sprite_manifest.json';

  Future<void> loadManifest({AssetBundle? bundle}) async {
    final generation = ++_loadGeneration;
    final assetBundle = bundle ?? rootBundle;
    final manifest = jsonDecode(
      await assetBundle.loadString(_manifestPath),
    ) as Map<String, dynamic>;
    if (manifest['type'] != 'character_animations') {
      throw const FormatException('Unsupported character animation manifest');
    }
    final width = manifest['cell_w'] as int;
    final height = manifest['cell_h'] as int;
    final duration = manifest['frame_ms'] as int;
    if (width <= 0 || height <= 0 || duration <= 0) {
      throw const FormatException('Invalid animation dimensions or timing');
    }
    final bytes = await assetBundle.load(_sheetPath);
    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    final ui.Image image;
    try {
      image = (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
    var committed = false;
    try {
      if (generation != _loadGeneration) {
        throw StateError('Wizard animation load cancelled or superseded.');
      }
      final groups = _buildAnimations(
        manifest,
        image,
        width,
        height,
        duration / 1000,
      );
      animations = groups;
      current = WizardAnimationState.idleRight;
      size = Vector2(width.toDouble(), height.toDouble());
      final previous = _image;
      _image = image;
      committed = true;
      previous?.dispose();
    } finally {
      if (!committed) image.dispose();
    }
  }

  @override
  void onRemove() {
    _loadGeneration++;
    animations = const {};
    _image?.dispose();
    _image = null;
    super.onRemove();
  }

  static Map<WizardAnimationState, SpriteAnimation> _buildAnimations(
    Map<String, dynamic> manifest,
    ui.Image image,
    int width,
    int height,
    double stepTime,
  ) {
    final groups = manifest['animations'] as Map<String, dynamic>;
    final frames = manifest['frames'] as List<dynamic>;
    final result = <WizardAnimationState, SpriteAnimation>{};
    for (final entry in groups.entries) {
      final group = entry.value as Map<String, dynamic>;
      final indices = (group['frames'] as List<dynamic>).cast<int>();
      if (indices.isEmpty) {
        throw FormatException('Empty animation group: ${entry.key}');
      }
      result[_stateForManifestKey(entry.key)] = SpriteAnimation.spriteList(
        [
          for (final index in indices)
            _sprite(image, frames, index, width, height),
        ],
        stepTime: stepTime,
        loop: group['loop'] as bool,
      );
    }
    if (!result.containsKey(WizardAnimationState.idleRight)) {
      throw const FormatException('Missing idle_right animation');
    }
    return result;
  }

  static Sprite _sprite(
    ui.Image image,
    List<dynamic> frames,
    int index,
    int width,
    int height,
  ) {
    if (index < 0 || index >= frames.length) {
      throw FormatException('Invalid frame index: $index');
    }
    final frame = frames[index] as Map<String, dynamic>;
    final rect = (frame['rect'] as List<dynamic>).cast<int>();
    if (rect.length != 4 ||
        rect[0] < 0 ||
        rect[1] < 0 ||
        rect[2] != width ||
        rect[3] != height ||
        rect[0] + rect[2] > image.width ||
        rect[1] + rect[3] > image.height) {
      throw FormatException('Invalid frame rect at index $index');
    }
    return Sprite(
      image,
      srcPosition: Vector2(rect[0].toDouble(), rect[1].toDouble()),
      srcSize: Vector2(width.toDouble(), height.toDouble()),
    );
  }

  static WizardAnimationState _stateForManifestKey(String key) => switch (key) {
    'idle_right' => WizardAnimationState.idleRight,
    'walk_right' => WizardAnimationState.walkRight,
    'run_right' => WizardAnimationState.runRight,
    'turn' => WizardAnimationState.turn,
    'run_left' => WizardAnimationState.runLeft,
    'walk_left' => WizardAnimationState.walkLeft,
    'idle_left' => WizardAnimationState.idleLeft,
    'showcase_loop' => WizardAnimationState.showcaseLoop,
    _ => throw FormatException('Unsupported animation group: $key'),
  };
}
