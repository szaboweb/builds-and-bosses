# Coding Agent Contract

## Read Before Changing Code

- [Architecture](docs/ARCHITECTURE.md): read current PoC/MWP and affected
  responsibility contracts. Steam productive target requirements are planned,
  not evidence of implemented features.
- [Shared quality decision](docs/CODE_QUALITY.md): mandatory module-placement
  algorithm and ratchet policy.
- Inspect affected code/tests; read target sections only when changing that scope.

## Ownership and Size

- Core owns headless rules; game owns runtime/visuals; UI displays state and
  dispatches intent; platform adapters implement service contracts.
- Reuse the correct existing owner. A new responsibility needs a focused module,
  even below the line limit. Pass narrow data/contracts, not a whole game/context.
- Normal production file maximum: **800 physical lines after formatting**.
- At **700 lines**, or projected to reach 700, record current size, remaining
  capacity, feature-growth upper bound (including uncertainty), responsibility
  and the extend/reuse/extract decision in the task/PR summary.
- Extend only when responsibility remains coherent and the upper bound <=800.
  Otherwise reuse/extract/create a focused module. Legacy >800 must not grow;
  extract the touched responsibility before adding features.
- Do not bypass limits with compressed formatting, `part` splitting, blanket
  exclusions or baseline increases. Complexity matters independently of length.

## Validation and Change Discipline

- Preserve intended behavior; add focused tests for new contracts.
- Update architecture contracts when ownership changes.
- Run relevant Flutter analysis/tests and architecture/data validators.
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
