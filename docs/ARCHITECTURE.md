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

## TacticalModeGame Coordinator Boundaries

The current coordinator is planned to split into five focused services:

- `GameInputController`: keyboard/tap input to game intent.
- `CombatCoordinator`: action execution, target selection, cooldown checks, and combat-engine calls.
- `GamePhaseController`: realtime/planning/executing/cooldown/victory/defeat transitions.
- `CombatTimerController`: elapsed combat time, Tactical Mode pause/resume, and completed-run duration.
- `BuildCombatController`: hero/boss build state, stat-derived combat modifiers, active/passive ability effects, and equipment-set effects.

The controllers communicate through domain models and events. No controller owns Canvas rendering or Flutter widgets.

## Physics and Collision (Forge2D)

Simulation is delegated to Flame's Forge2D (Box2D port). We do not write a custom solver; we derive physical parameters from D&D stats and feed them to Forge2D bodies.

- Stat mapping:
  - **STR** drives dynamic body mass. Equipment changes and stat changes recompute `MassData` (via fixture `density` + `resetMassData()`, or explicit `setMassData`), so `beginContact` knockback falls out of the solver from the current masses. Ability-driven knockback stays an explicit `applyLinearImpulse`.
  - **DEX** drives `linearVelocity` caps, movement force, airborne control (wind/storm levels), `friction`, and `linearDamping` — how sharply a character turns and how far it slides on icy or slick ground.
  - **CON** drives stagger resistance and damping applied to incoming impulses. Equipment weight adds to effective mass.
- Mass is recomputed on equipment/stat change events, never per frame.
- The Forge2D `Body` is the single source of truth for position and velocity. Components apply forces and impulses (`applyLinearImpulse`, `applyForce`); they never write transforms directly.
- Body types: characters and projectiles are `dynamic`, level geometry is `static`, moving platforms are `kinematic`.
- Hitboxes and hurtboxes are `isSensor` fixtures and are always distinct from the collision fixture and from sprite dimensions. Collision categories/masks separate hero, enemy, projectile, trap, and terrain.
- Fast projectiles set the `bullet` flag so continuous collision detection prevents tunneling.
- The world steps on a fixed timestep and rendering interpolates. Identical seed plus identical input must produce an identical run regardless of FPS.
- Stat-to-physics derivation (mass, impulse magnitude, damping, speed caps) lives in `lib/core/` and is unit-testable without Flame; `lib/game/` only wires the derived values into Forge2D bodies.
- D&D resolution (dice, damage, saves) stays in `core`; Forge2D only resolves spatial consequences.

## Component Composition

- `CharacterComponent` owns the Forge2D body; stats, cooldown/resource timers, and animation state attach as separate child components.
- Components hold no D&D formulas: they dispatch intent to core services and translate domain results into impulses or visuals.
- Heroes, bosses, minions, and projectiles reuse the same composition so new classes are configuration, not new class hierarchies.

## Interactive Environment (INT)

INT gates environmental manipulation, turning level decoration into tactical tools.

- `InteractiveEnvironmentComponent` renders as a plain sprite below its INT threshold. At or above the threshold it gains a Forge2D body plus an `InteractionSensor` fixture and becomes highlightable and activatable.
- Activation switches the body from `static` to `dynamic`, letting gravity and mass drive collapses, avalanches, and moving structures.
- Resulting damage is still resolved by core D&D rules; Forge2D only supplies impact momentum and displacement.
- INT thresholds, activation effects, and physics parameters are declared in level JSON, not in code.
- Each interactive element has a limited activation count per run so environments cannot become infinite damage sources.
- Environmental collapses run inside the fixed-timestep world, keeping runs reproducible from the same seed.

## Status Effects and Minion Influence

- DoT effects (poison, curse, bleed) are timer-driven tick sequences, not flat totals. CON scales the interval between ticks and the total duration, so high CON means fewer, slower ticks. CON also acts as passive mitigation against environmental/trap damage.
- Each entity owns a `DamageOverTimeTracker`. An entry records `sourceId`, `damageType`, `tickDamage`, `tickInterval`, `remainingDuration`, `elapsedSinceTick`, `stacks`/`stackRule` (`refresh`, `stack`, `strongestWins`), and `revocable`.
- The tracker lives in `core` and advances on the fixed-timestep clock using an accumulator, so a long frame emits the correct number of ticks and total DoT damage is FPS-independent.
- CON scaling coefficients are clamped JSON values so no build can fully negate a DoT.
- DoT entries participate in the modifier pipeline: a mid-run CON change recomputes `tickInterval` and `remainingDuration` from the next tick onward; damage already dealt is never retroactively adjusted.
- The tracker exposes a per-run summary (total DoT damage per type, longest active curse) that feeds the scoreboard curse metric and the death screen.
- DoT timers advance on the fixed-timestep clock so replays stay deterministic. Tick rate, tick damage, duration, and CON scaling curves are JSON config.
- CHA defines a minion influence threshold: below a configured HP percentage a minion becomes eligible for a Demoralize/Charm attempt, resolved as a CHA-based check against the minion's Will save in `core`.
- A converted minion switches faction (collision category and AI target) for a CHA-scaled duration; it is AI-driven, not player-controlled. A failed attempt may enrage the minion.
- Threshold, duration, concurrent-conversion limit, and failure consequences are data-driven per boss.

## Perception Layers (WIS)

INT opens the external world (level geometry); WIS opens the internal one (enemy structure and hidden routes).

- `WeakPointComponent` is a separate Forge2D sensor fixture with its own collision category. It is inactive and unhighlighted below the WIS threshold.
- Hits on an active weak point apply a critical multiplier resolved in `core` and may interrupt the enemy's attack by cancelling its animation state.
- `HiddenRouteComponent` gates alternate paths (maintenance tunnels, trap dead zones): below the WIS threshold the geometry stays blocking and unmarked; above it the blocking fixture is disabled or converted to a sensor and the route is highlighted.
- Weak point placement, size, damage multiplier, WIS thresholds, and focus cooldowns are per-boss/per-level JSON.

## Stat to Engine Map

| Stat | Engine system |
|:---|:---|
| STR | Forge2D `MassData`, impulses, knockback |
| DEX | `linearVelocity` caps, `friction`, `linearDamping`, air control |
| CON | DoT tick timers, environmental damage mitigation |
| INT | `InteractiveEnvironmentComponent` (static to dynamic activation) |
| WIS | `WeakPointComponent`, `HiddenRouteComponent` |
| CHA | Minion influence threshold and faction switching |

## Modifier Pipeline

Stats never drive Forge2D bodies directly. The chain is:

```text
base stats -> modifier layers -> effective stats -> derived parameters -> body / capability set
```

- Modifier layers evaluate in a fixed order: base, equipment/set bonuses, feats and enhancements, buffs, curses/debuffs, environmental and seasonal modifiers. The order is part of the determinism contract.
- Effective stats are cached and recomputed only when a modifier is added, expires, or changes (dirty flag) — never per frame.
- Recomputation ends in a single apply step that writes `MassData`, `friction`, `linearDamping`, and speed caps. No other code path mutates stat-derived physics values.
- Modifiers carry separate flat and multiplicative parts and are removed by source, followed by full re-evaluation, so revocation never accumulates floating-point drift.
- Threshold-gated abilities (INT environment activation, WIS weak points and hidden routes, CHA charm) live in a capability set rebuilt on each recomputation; dropping below a threshold immediately disables the corresponding sensors and highlights.
- Each ability declares `revocable` behaviour for effects already in flight (a collapsed rock stays collapsed; a charm duration may shorten).
- Thresholds use hysteresis (distinct enter/exit values or a minimum hold time) so pulsing curses cannot flap ability state.
- Body and fixture mutations are queued and applied between physics steps, never inside a contact callback.

## Control Pipeline

Input is never mapped directly to motion. The chain mirrors the modifier pipeline:

```text
raw input -> InputIntent -> ControlModifier layers -> EffectiveControl -> Forge2D force/impulse
```

- Keyboard, mouse, and controller are normalised into a device-agnostic `InputIntent` (`moveAxis`, `jump`, `attack`, `dodge`, `parry`, `interact`, `focus`, `tacticalPause`). Gameplay code never reads raw key codes.
- Stat layer: DEX scales acceleration, turn sharpness, air control, and coyote/input-buffer windows; STR scales mass and therefore start/stop inertia; CON scales stagger and post-interrupt recovery.
- State and environment effects (stun, freeze, root, inverted controls, silence, encumbrance, ice, wind, mud, underwater, void delay) are `ControlModifier` data entries. Branching on specific states inside movement code is forbidden.
- A `ControlModifier` declares `source`, `priority`, `speedMult`, `accelMult`, `frictionOverride`, `externalForce`, `axisTransform`, `inputDelay`, `blockedActions`, `duration`, and `revocable`. All fields are optional with defaults so schema growth stays backward compatible.
- Layers evaluate in fixed `priority` order and the result is clamped, so stacked effects cannot produce an unplayable state except for an explicitly declared full stun.
- Manual mode, Auto-Roll mode, and Tactical Pause all emit the same `InputIntent` type; auto-combat synthesises dodge/parry intents from saving throws rather than bypassing the pipeline.
- `InputIntent` and `EffectiveControl` are serialisable and recorded in the debug replay, so a run reproduces from the same seed plus intent stream.
- Each new control modifier type requires a headless test driving intents and asserting derived movement parameters.

## Sprite and Animation Pipeline

- Rendering uses `SpriteAnimationComponent` by default and `SpriteBatch` for high-count enemy waves.
- Sprites are packed into texture atlases and drawn batched; per-character/per-boss atlases keep draw calls low and FPS stable.
- Animation playback speed is data-driven and scalable at runtime by DEX, attack speed, or the current action. No hard-coded frame durations.
- Frames expose animation events (active hitbox window, parry frames, footstep audio). Combat logic subscribes to these events instead of reading raw frame indices.
- The visual/marionette layer is attached to the Forge2D body and never writes back into physics state.
- Animation frames carry no root motion: every pose shares one vertical axis and one baseline. Displacement comes only from the Forge2D body.
- The locomotion state is selected from body velocity and the ground sensor (`|vx|` thresholds for idle/walk/run, vertical velocity for jump/fall), never directly from the pressed key.
- Playback is stride-synced to avoid foot sliding: `stepTime = strideLength / max(|vx|, vMin)`, where `strideLength` is per-animation data. This is also how DEX indirectly scales animation speed.
- A velocity sign flip plays the non-looping turn frames as a transition without interrupting physics movement.
- Action animations (attack, parry, dodge) override the locomotion state but not the body; i-frames and hitbox windows come from animation events.
- Missing or invalid sprites render a placeholder and raise a developer warning; loading failures must not crash the game.

## Data-Driven Values

- Stats, weapons, abilities, cooldowns, level parameters, and Forge2D tuning values (density, friction, restitution, damping, gravity, acceleration, knockback impulse multipliers, i-frame duration) are loaded from versioned JSON, never hard-coded.
- Animation definitions (frame count, order, speed, looping, events) are data as well, so a new class can ship without code changes.
- Every new config value requires a schema entry, safe-range validation, and a headless test.

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
- The game is strictly single-player and offline-first: gameplay must never require internet access.
- Combat statistics are written to a local cache first. A future Steam adapter may sync the same immutable run record to the community Hall of Fame, but sync failure must never block gameplay.
- Every new rule or config value requires a headless test.

## Debug Replay

Combat runs use a configurable Dice seed and can be represented by a JSON
`DebugReplaySnapshot` containing the ruleset, hero, boss, action pipeline, and
outcome. A failing run can therefore be reproduced from the same seed instead
of relying on a live browser session.

The replay model lives in `app/lib/core/debug/`; it must remain independent of
Flutter rendering and Flame components.