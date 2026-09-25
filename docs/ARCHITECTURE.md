# Builds & Bosses Architecture

## Core Principle

Game rules and presentation are separate contracts.

`app/lib/core/` owns deterministic, headless Dart logic:

- D&D rules, dice, stats, combat resolution, actions, cooldowns, inventory, and platform-service contracts.
- No Flutter widgets, Material UI, Flame components, Canvas rendering, or platform-specific UI. `flutter/foundation.dart` is allowed only for headless observable state such as `ChangeNotifier`.
- All tunable gameplay values belong in config objects with JSON serialization.

`app/lib/game/` owns Flame runtime behavior:

- World entities, movement, camera, collision, animation, projectiles, and VFX.
- Components delegate attacks, dice, stats, and inventory decisions to `core`.
- Components render results; they do not implement D&D formulas or create uncontrolled RNG.

`app/lib/ui/` owns Flutter presentation:

- HUDs, overlays, controls, mode indicators, and combat-log presentation.
- Widgets dispatch intent to the game and read observable state.
- Widgets do not calculate damage, movement physics, dice, or inventory rules.

## Required Flow

```text
Input -> TacticalModeGame -> core action/combat service -> domain result
      -> CombatLogger/state notifier -> Flame component or Flutter overlay
```

The same domain service must be usable from realtime combat, Tactical Mode, auto-combat, and tests.

## Enforcement

Run the architecture validator before committing:

```powershell
pwsh -NoProfile -File tooling/validate_architecture.ps1
```

The validator is also a required GitHub Actions step. The local Git hook is installed by `setup.sh`.

## Data Naming and Schemas

- Data filenames use lowercase `snake_case`: `boss_001_malakar.json`.
- Schema identifiers are versioned: `hero_save/v1`, `hero_defaults/v1`, `boss/v1`.
- Every data file must contain `_schema`.
- D&D ability keys (`STR`, `DEX`, `CON`, `INT`, `WIS`, `CHA`) are an intentional domain exception to lowercase key naming.
- Numeric values are validated for safe ranges before data can pass the hook or CI.
- Schema changes create a new version; old saves are migrated explicitly rather than silently reinterpreted.

Run data checks with:

```powershell
pwsh -NoProfile -File tooling/validate_data.ps1
```

## Extension Rules

- Add new combat or spell rules under `lib/core/dnd/` or `lib/core/combat/` first.
- Add new visuals under `lib/game/components/` only after the domain result exists.
- Add inventory rules under `lib/core/inventory/`; UI only displays and dispatches inventory intent.
- Add Steam, Cloud Save, and achievements through `PlatformServices`; do not import Steam APIs into core rules.
- Every new rule or config value requires a headless test.