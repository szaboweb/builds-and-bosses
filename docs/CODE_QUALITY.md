# Module Quality and Shared Agent Decision

## Status

The shared Dart AST/size/import/format gate is implemented in
`tooling/code_quality`. The local pre-commit hook checks an isolated index
snapshot without changing the working tree or index. PR CI runs the same gate,
full analysis/tests and a web release build by workflow definition; a tooling
workflow is configured for Ruff, PSScriptAnalyzer and ShellCheck. These checks
passed locally; remote workflow results have not yet been inspected.
Existing Gitleaks CI is retained; no new local Gitleaks result is claimed.
GitHub branch protection is still intentionally inactive: these workflows do
not themselves make merging impossible when checks fail.

## File Size

Count physical lines in the persisted, normally formatted source, including
comments and blank lines. Report executable/code lines separately; do not
compress formatting or remove useful documentation to satisfy the limit.

- **Traffic Light File Size Zones:**
  - 🟢 **Green (0 – 349 physical lines): Safe Expansion & Sweet Spot Zone.** Coherent features
    can be added normally. The targeted size for new and extracted modules is **150 – 250 lines**
    to optimize LLM attention and prevent context amnesia.
  - 🟡 **Yellow (350 – 549 physical lines): Caution & Proactive Extraction Zone.**
    Prohibit adding new responsibilities. If extending the existing owner, first
    extract an existing sub-concern so the file drops comfortably into the Green Zone.
    At **550 lines or above**, or when a feature is expected to reach 550:
    mandatory capacity/responsibility review before adding code.
  - 🔴 **Red (550 – 650 physical lines): Hard Ceiling & Ban on Feature Growth.**
    **650 physical lines is the maximum** for new or compliant production source files.
    Existing files above 650 are legacy debt: no net growth; extract the touched
    responsibility before extending it. A baseline is not permission to grow.
- Data-heavy files, tests and generated sources need explicit separate profiles,
  not blanket folder exemptions. Do not silently classify logic as data.

A short but tangled function can fail quality review even in a 100-line file.
The file-size limit never replaces method/complexity/import-boundary checks.

## Deterministic Decision Procedure

Use this order for every feature, whether authored by a human or an agent:

1. **Classify current versus target scope.** Do not implement a target migration
   unless requested. Read the affected responsibility contract.
2. **Find prior art.** Reuse the existing owner/helper if it owns this behavior.
3. **Identify ownership.** A distinct state lifecycle, rule set, adapter,
   rendering concern or independently testable workflow is a separate
   responsibility. Put it in a focused module even if the current file is short.
4. **Measure the existing file.** Include planned helpers and tests/updates in
   the estimate for each affected file; do not equate total feature lines with
   the growth of just one file.
5. **Calculate capacity:** `800 - current physical lines`. At the 700 trigger,
   record estimated growth, an uncertainty allowance and the final upper-bound
   estimate. The upper bound must be at most 800. If there is no credible bound,
   extract/create a focused module rather than guessing.
6. **Check clarity:** does the addition preserve one coherent owner, explicit
   dependencies, reviewable methods and independent tests? If not, extract
   before adding it, regardless of spare lines.
7. **Choose the same outcome from the same evidence:**
   - Same responsibility, clear structure, measured upper bound <=800:
     extend the existing module.
   - Distinct responsibility or insufficient/uncertain capacity:
     reuse another proper owner, or create/extract a focused module.
   - Legacy >800: extract the touched responsibility; do not extend the monolith.
8. **Verify the result.** Recount after normal formatting, run relevant tests
   and validators, and update responsibility contracts only if ownership changed.

At the 700 trigger, include this concise decision in the task/PR summary:

```text
Owner: <module and responsibility>
Current lines: <N>
Estimated growth + uncertainty allowance: <N + N>
Expected upper bound / remaining capacity: <N / N>
Decision: extend | reuse | extract/new module
Reason: <ownership, dependencies, readability>
Validation: <exact commands and outcomes>
```

Do not create a Markdown note per feature. Use the task/PR discussion for the
decision, and architecture documentation only for enduring contracts.
This is a shared algorithm, not a guarantee that agents estimate identically;
the measured gate and review resolve disagreements.

## Ratchet Contract

The implemented shared checker is callable from an editor task, hooks and CI:

- New/compliant production files: enforce 800; 700 emits a required review signal.
  A counter cannot decide responsibility; require explicit decision evidence.
- Existing over-limit files/symbols: preserve per-file/per-symbol baselines and
  prohibit regression. Improvement elsewhere does not offset a regression.
- New methods in grandfathered files still follow normal complexity limits.
- Measure Dart methods/complexity with a pinned AST parser, not regex.
- Enforced method/complexity thresholds: 80 physical lines per method,
  cyclomatic 15, cognitive 20, control-flow nesting 4, parameters 7.
  An initial measured inventory and parser tests accompany enforcement.
  Flutter widget nesting is distinct from control-flow nesting.
- Detect disallowed imports/cycles with resolved source/import relationships.
- Baseline updates are explicit, reviewed and never automatic in a hook.
  Any increase requires user/maintainer approval and a scoped justification.
- Renames/moves must not erase debt. Missing tools/invalid baselines fail visibly.
- Fast pre-commit checks use an isolated staged snapshot, including partial
  staging, without mutating/stashing/resetting the user's working files.
- PR CI is configured to compare against the target merge-base and publish a status.
  Branch protection must actually be configured before calling it mandatory.
- Full analysis/tests run locally on demand and are configured in CI; no
  pre-push hook is installed. Keep the commit gate inexpensive.

## Enforced Profiles and Commands

- Production Dart: `app/lib` and the checker's own `lib`/`bin`. Physical lines
  include comments/blanks, without counting a trailing newline twice.
- Tests: formatter and analyzer/test runner; no production-size exemptions
  are inferred from data-looking code. Test files have a separate profile.
- Methods/constructors/functions/closures: 80 lines, cyclomatic 15,
  nesting-weighted cognitive 20, control-flow nesting 4, parameters 7.
  Nested closures are measured separately. This cognitive definition is a
  project metric, **not SonarQube compatibility**. Comments/string contents
  are not parsed as control flow.
- Dart typing: strict casts/inference/raw types. Async/resource lints include
  unawaited/discarded futures, subscription/sink ownership and throw-in-finally.
- Python tooling: pinned Ruff 0.12.12, fatal syntax/name errors and bugbear
  profile; not Dart linting. PowerShell: pinned PSScriptAnalyzer 1.24.0 with
  explicit reliability rules. Shell: ShellCheck 0.10.0 for the commit hook.
- Import/export graph: relative and this repository's package URIs,
  conditional alternatives, forbidden layer dependencies and cycles.
  The existing headless `flutter/foundation.dart` and `flame/extensions.dart`
  bridges are explicitly retained; no general Flutter/Flame core exemption.

From the repository root (Dart/Flutter must be on PATH, or configure the local
`buildsAndBosses.dartPath` git key for the hook):

```powershell
git config core.hooksPath .githooks
git config buildsAndBosses.dartPath C:\src\flutter\bin\dart.bat
Push-Location tooling\code_quality
dart pub get --enforce-lockfile
dart analyze
dart test
dart run bin\check.dart report
Pop-Location
.\tooling\validate_quality.ps1 -BaseRef HEAD
.\tooling\validate_quality.ps1 -Staged -BaseRef HEAD
Push-Location app
flutter analyze
flutter test
Pop-Location
python -m pip install -r tooling\requirements-quality.txt
python -m ruff check tooling
Install-Module PSScriptAnalyzer -RequiredVersion 1.24.0 -Scope CurrentUser
.\tooling\validate_scripts.ps1
.\tooling\test_checked_process.ps1
```

The initial baseline is an explicit inventory, not a claim that legacy
functions are small. `init` refuses to overwrite it. Hook/CI reject baseline
metric increases relative to HEAD/target merge-base. They also measure the
reference source independently: a legacy improvement cannot regress merely
because its committed baseline was not tightened. Below-threshold metrics
may vary within normal limits. Reduce baseline debt entries in reviewed
changes; do not regenerate the entire snapshot.

Exact file renames and uniquely identifiable unchanged method bodies retain
their debt; ambiguous moves are checked against normal limits (fail safely).
Copies do not gain another exemption from a still-present owner. An extracted
method from a still-present legacy file must satisfy normal method limits.

Changed >=700-line files require `capacity_reviews.json` evidence, bound to
the source hash printed by `report`, normalized for CRLF/LF. Example entry:

```json
{
  "app/lib/game/example.dart": {
    "sourceHash": "<report hash>",
    "owner": "Input intent mapping",
    "upperBound": 780,
    "decision": "extend",
    "reason": "Same responsibility; growth estimate 20 plus 10 uncertainty."
  }
}
```

The upper bound must cover the measured file and fit its applicable ceiling.
This gate verifies evidence presence, not whether a human/agent's ownership
judgment is wise. Keep the detailed estimate in the PR/task summary too.
The initial frozen inventory is grandfathered; changed legacy files still
require new evidence. Future projected growth above 700 requires review before
coding even when the finished file remains shorter.

The staged snapshot needs restored app/parser dependencies and matching staged
manifest/lock files, but
executes the staged checker source and staged baseline. It never stashes,
resets or stages user files. CI is the full analysis/test gate; a local hook
can be bypassed, so protection/review remains necessary.
Cached package resolution metadata is copied only into the temporary snapshot,
preserving language-version-dependent formatting and resolving included lints.

## Reliability Contracts

Equipment layer loads use a 10-second deadline; the workshop uses 12 seconds
and cancels its operation on timeout/dispose. Superseded/late results cannot
commit. Failed operations retain the previous outfit/grid and allow retry.
Combat restart cancels the current plan and its completion callback.

Combat statistics/achievement calls each have a 10-second deadline and
structured warnings plus visible UI notification. Local preference acquisition
and writes are bounded, false write results throw, and overlapping statistics
appends are serialized. Offline `sync == false` means locally queued, not
a rejected local write. Desktop initialization is bounded and global handlers
are installed first.

A timeout does not cancel an OS/platform future. A timed-out durable write
may finish later; do not imply exactly-once persistence or automatically retry
it. Tests cover these failure boundaries, not every possible engine/SDK hang.

The Godot preview launcher and Aseprite export script check exit codes and
bounded completion. The Godot validation launcher also checks error output
and required validation evidence because it
can report script errors with exit 0. Sprite exports validate fresh temporary
outputs before replacing old assets; zero Aseprite exports fail.
This is not a blanket guarantee for all tools: the Python stylizer still
reports zero input PNG files as a successful zero-output run.
The process wrapper
terminates its specific child PID, not unrelated processes. It is not a general
process-tree/job-object supervisor.

## Modularization Priorities

The measured PoC has oversized player, builder, game coordinator and workshop
files. Extract by the responsibility table in ARCHITECTURE.md, keeping behavior
and public contracts stable. Start with the workshop's controller/panels/slots,
then the player renderer/locomotion/combat orchestration and game input/phases.

Avoid arbitrary line slices, catch-all utilities, excessive tiny forwarding
files, cyclic services, shared mutable state, or `part` as a size-limit bypass.
The goal is a small relevant reading context with a clear owner, not simply a
smaller number in a report.

## Token and Output Discipline

- All automated test executions must use `flutter test --reporter=compact` (or `rtk flutter test` if installed) to reduce output volume by 60–80% and preserve model context capacity.
- Iterative validation during development must target specific test files rather than executing the entire test suite on every change.
- Terminal commands should leverage `rtk` (Rust Token Killer) whenever available in the local environment.

