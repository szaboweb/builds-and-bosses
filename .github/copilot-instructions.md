# Repository Instructions

Follow the shared [coding agent contract](../AGENTS.md).
Read [current versus target architecture](../docs/ARCHITECTURE.md) and the
[module-placement decision](../docs/CODE_QUALITY.md) before changing affected code.

Production source maximum is 800 physical lines after normal formatting.
At 700 lines (or projected to reach it), record responsibility and feature
capacity before extending. Distinct responsibilities require focused modules
even below 700. Existing >800-line files must not grow; extract first.

Keep the current Flutter/Flame PoC separate from the Steam productive target.
Do not assume planned Forge2D, full replay or Steam integration already exists.
Use narrow typed contracts, preserve behavior, run relevant tests/validators,
and do not raise baselines or relax gates without explicit approval.

The detailed policy has one source of truth in the linked documents.
Run the shared AST/size/import/format ratchet; changed >=700-line files require
hash-bound capacity review evidence. Hooks check staged snapshots; PR CI also
checks merge-base regressions. Branch protection is not enabled automatically.
