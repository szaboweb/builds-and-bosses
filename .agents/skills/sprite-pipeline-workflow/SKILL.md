---
name: sprite-pipeline-workflow
description: >-
  Standardized pipeline for exporting 3D characters/bosses from Blender (.blend) into 2D sprite sheets,
  Aseprite project files (.aseprite), and integrating them into Builds & Bosses Flame components.
  Use this skill whenever converting 3D rigs, models, or animations into game sprites or adding new animated entities.
---

# 3D Blender to 2D Spritesheet & Aseprite Workflow

Use this skill to convert 3D `.blend` models and armature actions into deterministic 2D side-view spritesheets, bundled with Aseprite, and integrated cleanly into Flutter/Flame.

---

## 1. One-Command Automated Export

The workspace includes a turnkey automation script:

```powershell
.\tooling\export_blend_sprites.ps1 `
  -BlendFile "path\to\model.blend" `
  -OutDir "app\assets\images\characters\<name>" `
  -Action "Walk" `
  -Name "<name>_walk" `
  -ResolutionX 160 `
  -ResolutionY 64 `
  -ElevationDeg 12.0
```

### What this command does:
1. **Auto-detects Tools**: Finds `blender.exe` (Blender 5.2/4.2) and `Aseprite.exe` across standard Windows paths and environment variables.
2. **Headless Blender Render (`tooling/render_blend_to_sprites.py`)**:
   - Sets film transparent background (`film_transparent = True`).
   - Ignores helper / platform meshes (`Platform*`, `Helper*`).
   - Auto-orients side camera (orthographic, auto-calculates bounding box across all animation frames so no pixels clip).
   - Sets studio 3-point lighting: Key (warm white), Rim (hellish/golden silhouette highlight from top-rear), Fill (cool blue).
   - Renders individual transparent frames (`frame_01.png`, `frame_02.png`, ...).
3. **Headless Aseprite Packaging**:
   - Generates an `.aseprite` master project.
   - Exports horizontal spritesheet (`<name>_sheet.png`) and JSON metadata (`<name>.json`).
   - Exports animated GIF preview (`<name>.gif`).

---

## 2. Parameter Tuning Cheat-Sheet

| Entity Type | Typical Resolution (`-ResolutionX` $\times$ `-ResolutionY`) | In-Game Component Size | Camera Elevation (`-ElevationDeg`) | Notes |
|---|---|---|---|---|
| **Humanoid / Fighter** | $64 \times 64$ | `Vector2(24, 48)` | $0.0^\circ$ (pure profile) or $8.0^\circ$ | 13-frame Godot standard |
| **Quadruped / Beast Boss** | $160 \times 64$ | `Vector2(120, 48)` | $12.0^\circ$ – $15.0^\circ$ | Elongated body; slight tilt shows both heads / legs / back platform |
| **Large Dragon / Golem** | $192 \times 96$ or $128 \times 128$ | `Vector2(144, 72)` | $10.0^\circ$ – $16.0^\circ$ | Check bounding envelope for wing span |

---

## 3. Flutter & Flame Integration Checklist

1. **Register Asset Directory in `pubspec.yaml`**:
   ```yaml
   flutter:
     assets:
       - assets/images/characters/<name>/
   ```
2. **Component Inheritance**:
   - For enemies/bosses: Subclass `DummyEnemyComponent` (ensures combat coordinator, attacks, knockback, damage rolls, and tap callbacks work out of the box).
   - If player can land on its back: Set `isRideable = true` and override `rideableBackSurface`.
3. **Locomotion & Spritesheet Loading**:
   - In `onLoad()`: `final image = await game.images.load('characters/<name>/<name>_sheet.png');`
   - Split into `Sprite` slices: `Sprite(image, srcPosition: Vector2(i * frameW, 0), srcSize: Vector2(frameW, frameH))`.
   - In `update(dt)`: Synchronize animation phase with real speed:
     `animationPhase = (animationPhase + speed * dt / strideLength * frameCount) % frameCount;`
   - In `render(canvas)`: Flip horizontally when moving left (`isFacingLeft`):
     ```dart
     if (isFacingLeft) {
       canvas.translate(size.x, 0);
       canvas.scale(-1, 1);
     }
     ```
4. **Cognitive Complexity & Quality Gates**:
   - Keep `_updatePatrol` simple: extract boundary calculation to `_resolvePatrolBoundaries()`.
   - Run `.\tooling\validate_quality.ps1` before committing.
