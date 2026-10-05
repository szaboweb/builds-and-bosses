# Coding Agent Contract

## Read Before Changing Code

- [Architecture](docs/ARCHITECTURE.md): read current PoC/MWP and affected
  responsibility contracts. Steam productive target requirements are planned,
  not evidence of implemented features.
- [Shared quality decision](docs/CODE_QUALITY.md): mandatory module-placement
  algorithm and ratchet policy.
- [Naming conventions](docs/NAMING_CONVENTIONS.md): mandatory file, layer, and
  function naming standards enforced by quality gates and analyzer.
- Inspect affected code/tests; read target sections only when changing that scope.

## Ownership and Size

- Core owns headless rules; game owns runtime/visuals; UI displays state and
  dispatches intent; platform adapters implement service contracts.
- Reuse the correct existing owner. A new responsibility needs a focused module,
  even below the line limit. Pass narrow data/contracts, not a whole game/context.
- **Traffic Light File Size & Proactive Refactoring Rules:**
  - 🟢 **Green (0 – 349 physical lines): Safe Expansion & Sweet Spot Zone.** Features belonging
    to the file's cohesive responsibility can be added freely. The targeted size for new/extracted
    modules is 150–250 lines to optimize LLM attention and prevent context amnesia.
  - 🟡 **Yellow (350 – 549 physical lines): Caution & Proactive Extraction Zone.**
    Never add a new responsibility here. If extending the existing owner, first
    extract an existing sub-concern so the file drops comfortably into the Green Zone.
    At 550+ lines, record current size, remaining capacity, growth bound, and
    the extend/extract decision in the task/PR summary and capacity reviews.
  - 🔴 **Red (550 – 650 physical lines): Hard Ceiling & Ban on Feature Growth.**
    650 physical lines after formatting is the absolute maximum limit. No new
    features may be added to Red files without extracting touched concerns first.
    Legacy files >650 lines must strictly decrease in size.
- Do not bypass limits with compressed formatting, `part` splitting, blanket
  exclusions or baseline increases. Complexity matters independently of length.

## Validation and Change Discipline

- Preserve intended behavior; add focused tests for new contracts.
- Update architecture contracts when ownership changes.
- Run relevant Flutter analysis/tests and architecture/data validators.
- **Mandatory Token-Efficient Execution (CLI / Test Output):**
  - Whenever executing tests, the agent **MUST** use `flutter test --reporter=compact` (or prefix with `rtk` if available, e.g. `rtk flutter test`) to minimize output token consumption and avoid context window pollution with hundreds of verbose log lines.
  - When iterating or debugging a specific feature, always target the focused test file (e.g. `flutter test test/dummy_shove_test.dart --reporter=compact`) instead of running the whole suite repeatedly.
  - Use `tooling/quick_check.ps1 -TestFile <path>` for 1-step iteration: automatically formats changed files, runs the focused test with compact reporter, and executes the quality ratchet.
  - Use `rtk` CLI proxy prefix for standard shell commands (e.g. `rtk git status`, `rtk git diff`) whenever the `rtk` binary is available on PATH.
- Run `tooling\validate_quality.ps1`: it checks AST metrics, size, imports,
  cycles and changed-file formatting. The commit hook uses staged content.
  Restore the pinned checker dependencies first; missing tools fail the gate.
- Changed files at/above 700 require a source-hash-bound capacity review in
  `tooling/code_quality/capacity_reviews.json`, in addition to the task/PR summary.
- Do not read the entire generated baseline into agent context. Inspect only
  affected entries; use `dart run bin/check.dart report` for sizes/source hashes.
- Do not relax gates or raise debt baselines without explicit approval.
- Distinguish saved disk contents from unsaved editor copies; do not overwrite
  conflicting user edits. Never modify shared read-only attachment snapshots.

Agent instructions guide decisions; tested CI gates and human review enforce
them. Confirm instruction-loading support for the particular agent environment.
