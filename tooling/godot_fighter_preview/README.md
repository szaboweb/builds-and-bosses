# Fighter equipment pixelart preview

Standalone Godot 4 feasibility experiment. It does **not** migrate or integrate
with the Flutter/Flame application. The original Blender file is not modified.

## Run on Windows

Verified with the Steam Godot **4.7.2** executable:

```powershell
.\tooling\godot_fighter_preview\start.ps1
```

Open the editor instead:

```powershell
.\tooling\godot_fighter_preview\start.ps1 -Editor
```

For another installation, add `-GodotPath 'C:\path\to\Godot.exe'`. The launcher
imports the project before starting it and does not download or install anything.
Alternatively, import [project.godot](project.godot) in Godot and press F6 with
[preview.tscn](preview.tscn) open, or F5.

## Controls

- Helmet, chest armor and weapon selectors switch independent equipment slots.
  Each has an explicit **None** option. Switching does not restart the animation.
- Pause/resume, restart and the time slider inspect the existing walk cycle.
- Viewing direction rotates the camera around the character.
- Resolution selects 64x64 or 128x128 rendering, not a different camera scale.
  The fixed 512x512 display uses nearest-neighbor x8 or x4 scaling.
- Optional RGB posterization rounds each output channel to five levels (at most
  125 RGB combinations). This is **not** a curated pixelart palette or outline
  generator. It is off by default.

## How it works

[assets/fighter.glb](assets/fighter.glb) contains the fighter mesh parts,
materials, 17-bone skeleton and `Fighter_Walk`. The walk starts at zero and lasts
one second: Blender frames 1 through 25 at 24 fps, with frame 25 closing the loop.
Godot plays it continuously; this is not a baked sprite sequence.

The equipment is original, deliberately simple test geometry created by
[preview.gd](preview.gd). `BoneAttachment3D` nodes bind the helmet to `Head`,
chest to `Spine`, and sword to `Hand.R`. Geometry is authored in skeleton rest
coordinates and transformed into its attachment's bone-local space. The depth
buffer handles front/back occlusion, without ordering 2D equipment sprites.

An orthographic camera renders one isolated world into a `SubViewport`.
MSAA and screen-space AA are disabled. Camera size is fixed at 2.8; there is no
per-frame recentering or auto-cropping. Lighting is fixed, shadows are disabled.
The window has a minimum size to preserve integer-scaled presentation.

### Asset provenance / re-export settings

The source is the local `C:\Users\mrsza\Downloads\fighter.blend`, using its
restored `Fighter_Walk` action. The GLB is included so this project does not need
Blender installed to run.

For a replacement export, work in a disposable copy of the source, select only
`Fighter_Rig` and its armature-bound meshes, and set the rig object's location
and Euler rotation to zero. Keep the bone rest transforms and mesh bindings.
Export glTF Binary with:

- Selected Objects enabled; skins and animations enabled.
- Animation mode Actions; force sampling enabled; Apply Modifiers disabled.
- Scene frame-range limiting disabled, so the closing frame 25 is included.
- **Slide to Zero enabled**, so Blender's frame-1 offset does not add a pause.
- Export to `assets\fighter.glb`; do not overwrite the original Blender source.

The checked-in [import settings](assets/fighter.glb.import) use 24 fps.
The viewer explicitly enables linear looping for the imported walk.

## Validation

```powershell
.\tooling\godot_fighter_preview\start.ps1 -Validate
.\tooling\godot_fighter_preview\start.ps1 -Validate -Capture
```

The second command needs a functioning graphics device and opens a temporary
test window. It writes ignored images into `captures\`, including `viewer.png`
and 64/128-resolution renders from four directions, with nearest-scaled copies.
Headless validation checks transforms, not pixel output.

The verifier covers all **8 slot combinations x 4 walk phases x 8 viewing
directions x 2 resolutions**. It checks:

- Imported action duration, foot motion and matching loop endpoints.
- Bone attachment transforms and equipment camera bounds.
- Animation continuity across equipment changes, playback and pause.
- Independent UI selectors, nearest-neighbor integer scaling and camera mode.
- In rendered mode, a nonempty visible character and no foreground pixels
  touching the render border in every tested combination/phase/direction.

The launcher checks the process exit code **and** the log's zero-failure result,
including script errors; a Godot parse failure cannot be reported as a pass.

## Findings and limits

Validated on 2026-10-04, Godot 4.7.2, Compatibility/OpenGL, AMD Radeon RX 6600.
Both headless and rendered verification passed. A 120-frame viewer sample ran
at approximately 61 frames/s with the local display pacing. This is neither an
uncapped GPU benchmark nor a full-game performance guarantee.

Inspected front/back/side renders: attachments stay with the character and
equipment is naturally occluded by the body. The 64px view is crisp but loses
facial and small equipment details; 128px retains more of them. The surface
shading still looks like low-resolution 3D, not hand-authored pixelart.

This supports **continuing runtime-3D visual experiments** for combinable
equipment, not deciding on an engine migration yet. User approval of the style
is still required. Important production work remains:

- Skinned/articulated armor and hiding covered body regions; the rigid box
  chest is only an attachment demonstration and is not an anatomical fit.
- Weapon-family-specific attacks, grips and off-hand equipment.
- Clipping checks for actual armor shapes across the full motion library.
- Temporal edge stability, art-directed palette, outlines and lighting.
- Representative dungeon/multi-character performance and platform validation.

No attacks, new idle clip, physics, inventory rules or playable level are
implemented. See [the pipeline notes](../../docs/pixelart_pipeline.txt) for the
still-supported deterministic Blender-to-2D path.

## Flutter training-arena sprite bridge

The [Equipment Workshop](../../docs/EQUIPMENT_WORKSHOP.md) has a separate 3x3
armory containing this viewer's sample helmet, chest and sword. Its draggable
icons are exported directly from `_build_equipment()` meshes using
[export_equipment_icons.gd](export_equipment_icons.gd), with transparent 64px
output. Run it using the same Steam Godot command below, substituting
`res://export_equipment_icons.gd` for the script. No extra equipment variants
are invented. Matching body slots now dress the Flutter fighter using
[export_equipment_layers.gd](export_equipment_layers.gd): synchronized 13-frame
layers sharing the bare fighter's camera and baseline. The exporter checks
exact composition against Godot for all 8 combinations in every frame.

The existing Flutter arena now defaults to a **pre-rendered** version of this
fighter. It is not running Godot inside Flutter and does not expose the
runtime-3D equipment selectors. Its Equipment Workshop instead controls baked
equipment layers on matching body slots. The standalone viewer remains unchanged.

[export_flutter_sheet.gd](export_flutter_sheet.gd) generates
[the bundled atlas](../../app/assets/images/characters/fighter_godot/walk13_fighter.png):
13 transparent 64x64 cells, one static rest pose plus 12 distinct walk phases.
The camera is a horizontal right-facing side view, with fixed root projection
at pixel (32, 54). Left-facing rendering mirrors the atlas. Cells are never
cropped or individually aligned to the lowest foot.

Regenerate using the Steam Godot executable from PowerShell:

```powershell
$godot = 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
$project = Join-Path (Get-Location) 'tooling\godot_fighter_preview'
Start-Process -FilePath $godot -ArgumentList @('--path', ('"' + $project + '"'), '--script', 'res://export_flutter_sheet.gd') -Wait
```

The exporter requires a graphics device and checks transparent background,
visible geometry and at least eight distinct walk images. It also writes
ignored enlarged inspection frames to `captures\`.

The Flutter player preserves its 48x52 physics bounds, movement speed, jump,
flight, platform collisions and attack behavior. The 12-frame walking cycle
advances with horizontal distance (96 world pixels per cycle). Airborne motion
currently holds a stride pose: **dedicated jump/fall/flight clips are not yet
authored**. Weapons and attack VFX still use the existing Flutter presentation,
not new Godot attack animations. The sprite picker still supports bundled
legacy 32px atlases. Live AI publishing has been removed; the former Character
Workshop is now a [3x3 Equipment Workshop](../../docs/EQUIPMENT_WORKSHOP.md).

Validate the Flutter bridge from `app\`:

```powershell
flutter test test\fighter_animation_test.dart test\tactical_game_test.dart test\dnd_combat_test.dart
flutter analyze lib\game\components\player_component.dart test\fighter_animation_test.dart
```

Both commands passed during integration (24 tests; no analysis issues).
