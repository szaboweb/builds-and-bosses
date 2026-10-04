/// Rendering proportions for one fighter body archetype: sprite-sheet layout,
/// frame size and the world-space baseline used to anchor it under the
/// hitbox. See docs/ARCHITECTURE.md "Fighter visual renderer" responsibility
/// contract; this is the typed data half of that extraction.
class FighterBodyProfile {
  final String spriteSheetPath;
  final double frameSize;
  final int minFrameCount;
  final double rootBaselineY;

  /// Whether this body uses the Godot-exported, 13-frame walk cycle that the
  /// Equipment Workshop's frame-synced layers are built for.
  final bool usesEquipmentLayers;

  const FighterBodyProfile({
    required this.spriteSheetPath,
    required this.frameSize,
    required this.minFrameCount,
    required this.rootBaselineY,
    required this.usesEquipmentLayers,
  });

  /// The baked 13-cell, 64px Blender/Godot export (current default body).
  static const godotFighter = FighterBodyProfile(
    spriteSheetPath: 'characters/fighter_godot/walk13_fighter.png',
    frameSize: 64.0,
    minFrameCount: 13,
    rootBaselineY: 54.0,
    usesEquipmentLayers: true,
  );

  /// The legacy bundled 32px atlas selectable from the character builder.
  static const legacyBuiltIn = FighterBodyProfile(
    spriteSheetPath: '',
    frameSize: 32.0,
    minFrameCount: 5,
    rootBaselineY: 32.0,
    usesEquipmentLayers: false,
  );

  /// Resolves which profile a bundled character atlas path should render
  /// with. Unknown/legacy paths fall back to [legacyBuiltIn], preserving
  /// existing behaviour; new body archetypes register their own path here.
  static FighterBodyProfile forSheetPath(String path) =>
      path == godotFighter.spriteSheetPath ? godotFighter : legacyBuiltIn;
}
