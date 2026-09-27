import 'dart:convert';

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
}

class WizardAnimationController
    extends SpriteAnimationGroupComponent<WizardAnimationState> {
  WizardAnimationController()
    : super(
        size: Vector2.all(32),
        animations: const {},
        current: WizardAnimationState.idleRight,
      );

  static const _sheetPath = 'characters/wizard_13/walk13_rendered.png';
  static const _manifestPath =
      'assets/images/characters/wizard_13/walk13_sprite_manifest.json';

  Future<void> loadManifest({AssetBundle? bundle}) async {
    final assetBundle = bundle ?? rootBundle;
    final manifestText = await assetBundle.loadString(_manifestPath);
    final manifest = jsonDecode(manifestText) as Map<String, dynamic>;
    if (manifest['type'] != 'character_animations') {
      throw const FormatException('Unsupported character animation manifest');
    }

    final frameWidth = manifest['cell_w'] as int;
    final frameHeight = manifest['cell_h'] as int;
    final frameDuration = Duration(milliseconds: manifest['frame_ms'] as int);
    final frameData = manifest['frames'] as List<dynamic>;
    final image = await assetBundle.load(_sheetPath);
    final spriteSheet = SpriteSheet(
      image: await Flame.images.load(_sheetPath),
      srcSize: Vector2(frameWidth.toDouble(), frameHeight.toDouble()),
    );
    final animationGroups = manifest['animations'] as Map<String, dynamic>;
    final animations = <WizardAnimationState, SpriteAnimation>{};

    for (final entry in animationGroups.entries) {
      final state = _stateForManifestKey(entry.key);
      final group = entry.value as Map<String, dynamic>;
      final indices = (group['frames'] as List<dynamic>).cast<int>();
      final loop = group['loop'] as bool;
      final sprites = <Sprite>[];
      for (final index in indices) {
        final frame = frameData[index] as Map<String, dynamic>;
        final rect = (frame['rect'] as List<dynamic>).cast<int>();
        if (rect.length != 4) {
          throw FormatException('Invalid frame rect for ${entry.key}');
        }
        sprites.add(
          spriteSheet.getSpriteById(
            index % (manifest['cols'] as int),
            index ~/ (manifest['cols'] as int),
          ),
        );
      }
      animations[state] = SpriteAnimation.spriteList(
        sprites,
        stepTime: frameDuration.inMilliseconds / 1000,
        loop: loop,
      );
    }
    this.animations = animations;
    current = WizardAnimationState.idleRight;
    size = Vector2(frameWidth.toDouble(), frameHeight.toDouble());
    image.dispose();
  }

  static WizardAnimationState _stateForManifestKey(String key) => switch (key) {
    'idle_right' => WizardAnimationState.idleRight,
    'walk_right' => WizardAnimationState.walkRight,
    'run_right' => WizardAnimationState.runRight,
    'turn' => WizardAnimationState.turn,
    'run_left' => WizardAnimationState.runLeft,
    'walk_left' => WizardAnimationState.walkLeft,
    'idle_left' => WizardAnimationState.idleLeft,
    _ => throw FormatException('Unsupported animation group: $key'),
  };
}
