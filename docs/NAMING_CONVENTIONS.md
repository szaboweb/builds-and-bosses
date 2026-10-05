# Builds & Bosses — Naming Conventions

## 1. Overview & Purpose

This document establishes the repository-wide naming conventions for files, functions, methods, classes, and data structures.
These conventions are **strictly enforced** by:
1. `app/analysis_options.yaml` via `flutter analyze`.
2. `tooling/code_quality/lib/naming.dart` via `dart run bin/check.dart check` (AST-level verification).
3. `tooling/validate_architecture.ps1` via pre-commit and CI gates.

Any commit that violates these conventions will fail the local git hook and CI quality checks.

---

## 2. File Naming Conventions

All files across the repository must use lowercase `snake_case`.

| File Type / Layer | Rule & Pattern | Required Suffix | Examples |
|---|---|---|---|
| **Flame Components** | `^[a-z0-9_]+_component\.dart$` | `_component.dart` | `player_component.dart`, `arena_map_component.dart` |
| **Controllers & Coordinators** | `^[a-z0-9_]+_controller\.dart$` | `_controller.dart` | `player_locomotion_controller.dart`, `lighting_controller.dart` |
| **UI Overlays & Modals** | `^[a-z0-9_]+_overlay\.dart$` | `_overlay.dart` | `action_bar_overlay.dart`, `character_builder_overlay.dart` |
| **UI Screens** | `^[a-z0-9_]+_screen\.dart$` | `_screen.dart` | `equipment_workshop_screen.dart` |
| **UI Heads-Up Displays** | `^[a-z0-9_]+_hud\.dart$` | `_hud.dart` | `planning_hud.dart` |
| **Animators & Profiles** | `^[a-z0-9_]+_(animator\|profile\|appearance)\.dart$` | `_animator.dart`, etc. | `fighter_animator.dart`, `fighter_body_profile.dart` |
| **Core Domain Models** | `^[a-z0-9_]+\.dart$` | Descriptive noun | `character_stats.dart`, `combat_engine.dart`, `dice.dart` |
| **Platform Services** | `^[a-z0-9_]+_services\.dart$` | `_services.dart` | `platform_services.dart`, `local_platform_services.dart` |
| **Tests** | `^[a-z0-9_]+_test\.dart$` | `_test.dart` | `fighter_animation_test.dart`, `tactical_game_test.dart` |
| **Python Tools** | `^[a-z0-9_]+\.py$` | `.py` | `stylize_blender_renders_to_pixelart.py` |
| **PowerShell Scripts** | `^[a-z0-9_]+\.ps1$` | `.ps1` | `validate_quality.ps1`, `invoke_checked_process.ps1` |
| **Data & Schemas** | `^[a-z0-9_]+\.json$` | `.json` | `boss_001_malakar.json`, `equipment_sets.json` |

### Forbidden in File Names:
- ❌ CamelCase / PascalCase: `PlayerComponent.dart`, `ActionBar.dart`
- ❌ kebab-case / dashes: `player-component.dart`, `combat-engine.dart`
- ❌ Spaces or special characters.

---

## 3. Function & Method Naming Conventions

### 3.1. Language-Specific Casing

* **Dart**: Szigorúan `lowerCamelCase` (nyilvános) és `_lowerCamelCase` (privát). Belső alulvonás tilos (`bad_function_name` ❌).
* **Python**: `snake_case` (nyilvános) és `_snake_case` (privát).
* **PowerShell Functions**: `Verb-Noun` PascalCase jóváhagyott igékkel (pl. `Invoke-CheckedProcess`, `Add-Violation`).

### 3.2. Semantic Naming Patterns (Dart)

Function names must be intention-revealing. Use established domain verbs:

#### A. Commands & State Mutations (Igei előtag)
* `update*()`: Időalapú vagy input-alapú állapotfrissítés (pl. `updatePhysics`, `updateStats`, `updateLocomotionFrame`).
* `execute*()`: Terv, művelet vagy parancs végrehajtása (pl. `executePlan`, `_execute`).
* `cancel*()`: Folyamat azonnali megszakítása vagy visszavonása (pl. `cancelPlan`, `cancelEquipmentUpdate`).
* `start*()`, `stop*()`, `pause*()`, `resume*()`, `reset*()`: Életciklus és időzítők vezérlése (pl. `startPlanning`, `restartCombat`, `pause`, `reset`).
* `resolve*()`: Szabályalapú vagy harci kalkuláció levezetése (pl. `resolveMeleeAttack`, `_resolveLandings`, `_resolveSlash`).
* `set*()` / `apply*()`: Explicit állapotbeállítás vagy aszinkron tranzakció (pl. `setEquipment`, `setCharacterAppearance`, `applyHeroBuild`).
* `reload*()` / `load*()`: Erőforrás, atlasz vagy adat betöltése (pl. `reloadCharacterSheet`, `onLoad`).
* `trigger*()`: Esemény vagy hotkey reakció kiváltása (pl. `triggerHitReaction`, `triggerSlashHotkey`).
* `toggle*()`: Kétállapotú boolean kapcsoló (pl. `toggleDarkness`).

#### B. Queries & Predicates (Boolean visszatérési érték)
Minden logikai feltételt lekérdező függvénynek kötelező a segédigei előtag:
* `is*`: Állapot vizsgálata (pl. `isOnGround`, `isExecutingPlan`, `isRunning`).
* `can*`: Képesség vagy jogosultság vizsgálata (pl. `canReachMelee`, `canUse`).
* `has*`: Birtoklás vagy létezés vizsgálata (pl. `hasPlatform`).
* `should*`: Javasolt vagy esedékes döntés vizsgálata.

❌ Tilos: puszta melléknév vagy ige (pl. `ground()` helyett `isOnGround`, `reachMelee()` helyett `canReachMelee`).

#### C. Getters & Accessors
A Dart szabványnak megfelelően a getterek tulajdonságnevek, felesleges `get` előtag nélkül:
* `double get moveSpeed` (nem: `getMoveSpeed()`)
* `double get jumpVelocity` (nem: `getJumpVelocity()`)
* `String get characterSheetPath` (nem: `getCharacterSheetPath()`)

#### D. Event Handlers & Callbacks
* Rendszer/keretrendszer életciklus és bemeneti események: `on<Event>` (pl. `onKeyEvent`, `onTapDown`, `onLoad`, `onRemove`).
* Belső diszpécser / kezelő metódusok: `handle<Event>` vagy `_handle<Event>` (pl. `handleKeyEvent`).

---

## 4. Class, Type & Constant Naming

* **Classes, Enums, Mixins, Extension Types**: `UpperCamelCase` (pl. `PlayerComponent`, `CharacterStats`, `EquipmentSlot`).
* **Constants & Enum Values**: `lowerCamelCase` (pl. `godotFighterSheetPath`, `GamePhase.realtime`, `ActionType.slash`).
  - *Kivétel (Domain szabvány)*: D&D alaptulajdonságok (`STR`, `DEX`, `CON`, `INT`, `WIS`, `CHA`) nagybetűsek maradnak.
* **Constructors**:
  - Default: `ClassName()`
  - Named: `ClassName.namedConstructor()` `lowerCamelCase` formátumban (pl. `CharacterStats.fighterProtagonist()`).

---

## 5. Automated Verification

Módosítások előtt és után az ellenőrzés futtatható:

```powershell
# Dart analyzer lint ellenőrzés
cd app
flutter analyze lib test

# Quality gate (AST metrikák + naming konvenciók ellenőrzése)
cd ../tooling/code_quality
dart run bin/check.dart check
```
