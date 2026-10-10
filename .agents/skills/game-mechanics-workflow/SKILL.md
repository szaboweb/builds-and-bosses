---
name: game-mechanics-workflow
description: >-
  Standardized, token-efficient engineering procedure for creating or modifying in-game physics,
  emergent rules, damage formulas, and status effects in Builds & Bosses. Use this skill whenever
  adding, testing, or refactoring game mechanics, physics stats, dice/PRNG, or combat interactions.
---

# Game Mechanics & Physics Engineering Workflow

Use this skill to implement headless, deterministic gameplay systems in `app/lib/core/`
with minimal token consumption, zero trial-and-error, and 100% quality gate compliance.

---

## 1. Pre-Flight: Spec Synthesis & Golden Tables

Before writing any production code:
1. **Never guess formulas or scrape external links repeatedly**:
   Synthesize disparate inputs into a single markdown handoff in `docs/` (e.g. `docs/PHYSICS_AND_RULES_HANDOFF.md`).
2. **Mandatory Golden Tables**:
   Define at least 3 concrete test cases with exact inputs and calculated outputs:
   - Typical value (e.g. DEX 14 $\rightarrow$ 11 damage)
   - Boundary/Clamp value (e.g. DEX 24 $\rightarrow$ 0 damage, STR 1 $\rightarrow$ min 1 tile)
   - Edge/Immunity case (e.g. Weight > Push force $\rightarrow$ 0 movement)
   Tests must assert against these exact integers.

---

## 2. Headless Core Architecture (`app/lib/core/`)

Keep physics and rules completely decoupled from Flame visuals and rendering:
- **Pure Dart**: Zero Flame, zero Flutter imports in `app/lib/core/`.
- **Deterministic Fixed-Point**: Use `Fixed` (milli-units: 1000 = 1 tile, 200 = 1 ft). **Never use `double`**.
- **1 Capability = 1 Owner Stat**: Enforced by `CapabilityRegistry`. Stats derive capabilities; capabilities never modify base stats directly.
- **Modifier Ordering**: Base value $\rightarrow$ Flat additions $\rightarrow$ Multipliers (max per source group) $\rightarrow$ Overrides (priority) $\rightarrow$ Caps.
- **File Sizing**: Target 100–250 physical lines (🟢 Green Zone). Extract sub-concerns before crossing 350 lines.

---

## 3. Strict AST & Code Quality Ratchets

Every file must pass `tooling/validate_quality.ps1` on the first try:

| Rule | Threshold | Solution / Pattern |
|---|---|---|
| **Max Parameters** | **$\le$ 7** | Bundle into `<Name>Context`, `<Name>Config`, or `<Name>Breakdown`. |
| **Max Method Lines** | **$\le$ 80** | Extract private helpers (`_deriveStrengthCaps`, etc.). |
| **Max Nesting** | **$\le$ 4** | Return early / guard clauses. |
| **Naming Convention** | `lowerCamelCase` | **Do NOT use Dart operator overloads** (`+`, `-`, `<`, `==`). Use explicit methods: `add()`, `sub()`, `isLessThan()`, `hasSameValue()`. |
| **Private Constructors** | `lowerCamelCase` | Use `ClassName._internal()`, never `ClassName._()`. |

---

## 4. Token-Efficient Verification Commands

Always run targeted, compact commands to avoid context window pollution:

1. **1-Step Formatter + Test + Ratchet:**
   ```powershell
   tooling/quick_check.ps1 -TestFile app/test/core/..._test.dart
   ```
2. **Compact Test Runner:**
   ```powershell
   rtk flutter test test/core/..._test.dart --reporter=compact
   ```
3. **Quality Ratchet Gate:**
   ```powershell
   powershell -NoProfile -Command "& tooling/validate_quality.ps1"
   ```
4. **File Capacity Tracker:**
   ```powershell
   powershell -NoProfile -Command "& tooling/check_file_capacity.ps1 -ChangedOnly"
   ```
