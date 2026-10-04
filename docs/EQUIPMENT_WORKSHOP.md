# Equipment Workshop

The former Character Workshop has been removed. Its AI generation screen,
HTTP API client, Python backend/tests, ComfyUI workflows, procedural walk
generator and service startup tasks are no longer part of this repository.
The HTTP dependency used only by that client has also been removed.

Open **Felszerelés workshop** from the inventory icon in the training arena.
The workshop now provides a **3x3 equipped-body grid (9 slots)**, not 9x9.

- Every slot is selectable and labelled with its body location and contents.
  Layout, row by row: **neck / head / ring**, **main hand / chest / off hand**,
  **gloves / leg armor / boots**.
- Slot compatibility is enforced by `EquipmentGrid`, not only the UI.
  Helmet goes only to head, chest armor only to chest, sword only to main hand.
  Undefined item types, wrong slots and occupied targets are rejected.
- Workshop slots start empty. Beside them is a second 3x3 **Armory** grid.
- The armory contains the actual Godot preview's sample helmet, chest armor and
  sword. Their 64px transparent icons are rendered from the meshes in
  `preview.gd`, not drawn substitutes. These visual samples add no combat stats.
- Drag an armory item onto its matching empty workshop slot. Alternatively click the
  armory item, then the destination. This copies a sample from the catalog;
  the armory is not a finite inventory and its source item remains available.
- The selected outfit updates the game character immediately. Items cannot be
  dragged to unrelated body slots, including from one equipped slot to another.
- Armory arrows and keyboard Left/Right cycle through sets, wrapping at either
  end without changing workshop contents. The current catalog has **one real
  set**, so the arrows are disabled until additional sets are supplied.
- On narrow displays the two grids stay side by side and scroll horizontally.
- `EquipmentGrid` accepts typed `EquipmentItem` objects through `place`.
- Occupied slots display the item's name, ID and modifiers.
- **Felszerelés levétele** removes the item from both the grid and the fighter.
- Loading is transactional: a failed character-layer load is logged and shown
  as an error; the previous outfit and grid are retained.
- Layer loading has a 10-second deadline; the workshop callback has 12 seconds.
  Timeout unlocks the UI for retry. Closing the screen or cancelling a request
  invalidates it, so late loading/readiness results cannot equip old items.
- The grid survives closing/reopening the workshop in the current GameScreen.
  It is not saved to disk and resets when that screen/application is recreated.

This equips **visual layers on the Godot-rendered fighter**. Combat-stat
application, general item import, loot/inventory transfer and persistent saves
are not connected yet. Other bundled 32px characters have incompatible rigs;
remove fighter equipment before choosing them in the character builder.

The three item layers have the same 13 frames, 64px cell size, baseline and
camera as the body. Rendering uses the body's exact animation-frame index and
the same facing transform, including the held airborne pose. Equipped swords
replace the procedural class-weapon drawing (attack VFX stay unchanged).
No new attack/jump animations are implied.

`export_equipment_layers.gd` renders the real Godot attachments with the body
still participating in depth testing, then exports only changed pixels against
the bare fighter. The exporter checks that every base frame exactly matches
the existing fighter atlas and that composing the layers reproduces Godot's
render in all **8 combinations x 13 frames**. This avoids per-combination
atlases for these samples. Future gear with overlapping pieces must pass the
same composition checks; arbitrary overlapping/skinned armor is not certified.

The typed catalog is in `app/lib/core/inventory/godot_sample_equipment.dart`.
The screen accepts a list of `EquipmentSet` objects (up to 9 items per set);
new sets can be supplied there without changing the paging or drag/drop UI.
Each `EquipmentItem` optionally has an `iconAssetPath`, `equipmentSlot` and
`fighterLayerPath`. Equippable fighter items require the latter two.

Regenerate the bundled icons from the repository root with Steam Godot:

```powershell
$godot = 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
$project = Join-Path (Get-Location) 'tooling\godot_fighter_preview'
. .\tooling\invoke_checked_process.ps1
Invoke-CheckedProcess -Executable $godot -Arguments @('--path', ('"' + $project + '"'), '--script', 'res://export_equipment_icons.gd') -TimeoutSeconds 300 -FailurePattern 'SCRIPT ERROR:|ERROR:'
Invoke-CheckedProcess -Executable $godot -Arguments @('--path', ('"' + $project + '"'), '--script', 'res://export_equipment_layers.gd') -TimeoutSeconds 300 -FailurePattern 'SCRIPT ERROR:|ERROR:'
```

This requires graphics rendering. The exporter verifies visible, unclipped
items on transparent backgrounds and exits nonzero on validation/save errors.
Export the bare fighter first if its source model/camera/animation changes.

The fighter sprite, training arena, character-stat builder and bundled sprite
selection remain available. Blender/Godot rendering and deterministic
pixelart export tooling are retained; these do not use the deleted generator.
Previously generated art and external ComfyUI installations/models are not
deleted.

## Validation

From `app\`:

```powershell
flutter test test\equipment_workshop_test.dart test\inventory_test.dart test\fighter_animation_test.dart test\tactical_game_test.dart test\reliability_test.dart
flutter analyze
```
