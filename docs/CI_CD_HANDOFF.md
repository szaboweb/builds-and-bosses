# CI/CD handoff - 2026-10-04

## Purpose

Continue the repository reliability/modularity fixes first, then revisit the
GitHub Actions CI/CD consolidation in a new session.
The user requested a pipeline recommendation and then this handoff.
The CI/CD recommendations below are **not yet implemented or approved for execution**.
Do not assume permission to enable branch protection, publish to Steam, or
change remote repository settings merely from this document.

## Current checkpoint

- Repository: `szaboweb/builds-and-bosses`.
- Branch: `main`.
- Commit pushed successfully:
  `69e6feb155fdf0f39efbf3d7cf88cb5a2c76b645`.
- Commit title: Replace character generator with fighter equipment workshop
  and quality gates.
- Remote `main` was verified to match that commit.
- Working tree was clean after the push. This handoff is a subsequent change.
- GitHub Actions results for that push have **not been inspected**.
- A subsequent documentation consistency review corrected stale ratchet,
  replay and equipment-swapping statements in the local documentation.
  Those corrections and this handoff are not part of the checkpoint commit.

The completed session replaced the AI character generator with a typed 3x3
equipment workshop and adjacent armory, integrated the baked Godot fighter
and equipment layers, hardened selected async/persistence/process paths,
and introduced quality ratchets and shared coding contracts.

Read:

- [Agent contract](../AGENTS.md)
- [Current PoC versus Steam target and ownership](ARCHITECTURE.md)
- [Quality policy, commands and limitations](CODE_QUALITY.md)
- [Equipment behavior and exports](EQUIPMENT_WORKSHOP.md)
- [Branch workflow](TEAM_WORKFLOW.md)

## Existing workflows

| Workflow | Current behavior |
|---|---|
| [Code quality](../.github/workflows/quality.yml) | PR, main/dev push, manual; Windows runner; AST/format ratchet, architecture/data/process checks, checker tests/analyze, full Flutter analyze/tests, web release build |
| [Tooling quality](../.github/workflows/tooling-quality.yml) | PR, main/dev push, manual; Linux Ruff/ShellCheck and Windows PSScriptAnalyzer/process tests |
| [Windows build](../.github/workflows/windows-build.yml) | main push or manual; repeats architecture/data/analyze/tests, builds/uploads Windows release; optional Steam upload in the same job |
| [Secret scan](../.github/workflows/secret-scan.yml) | Push/PR Gitleaks |

Branch protection is intentionally inactive in current single-developer mode.
Workflow definitions do not themselves prevent merging a failing change.
There is no separate approved release-candidate/deployment flow yet.

## Recommended architecture

Use **GitHub Actions**, not a separate Jenkins/build-server installation.
GHA is the CI/CD execution platform, not an alternative to CI/CD.
Consolidate existing workflows rather than adding duplicate checks.

| Pipeline | Trigger | Responsibility |
|---|---|---|
| PR quality | PR to dev/main | Ratchet, formatting, architecture/data, full analysis/tests, tooling lint, secret scan |
| Build verification | PR and integration push | Web and Windows release compilation; downloadable test artifacts |
| Release candidate | Protected version tag or manual | Validated Windows package with version, commit SHA, checksum and retained artifact |
| Steam deployment | Manual approval | Upload the existing approved artifact to Steam internal/beta; verify actual upload result |

```text
feature/fix -> PR -> quality gates + build -> dev/main
                                              |
                                  release candidate artifact
                                              |
                                      manual approval
                                              |
                                    Steam internal/beta
```

### CI consolidation

- Run platform-independent Flutter analysis/tests on Linux where validated.
- Keep Windows compilation and platform-specific PowerShell checks on Windows.
- Test Windows compilation on PRs, not only after main push.
- Avoid repeated full test suites without a platform-specific reason.
- Add concurrency cancellation for obsolete PR runs.
- Bound jobs with timeouts; pin toolchains and cache dependencies.
- Keep status names stable and document actual GitHub-displayed names.
- Preserve merge-base ratchet behavior and negative tests during restructuring.

### Build/deploy separation

- Build jobs receive no Steam credentials.
- Deployment uses a protected GitHub Environment, e.g. `steam-internal`.
  Environment settings and approval availability must be verified for the
  repository's GitHub plan before claiming enforcement.
- Test and publish the **same binary**. Do not rebuild during deployment.
- Associate artifacts with version, commit SHA and checksums.
- Verify artifact provenance and the selected source run/commit.
- Check SteamCMD exit code and actual upload success evidence with a deadline.
- Confirm Steam authentication/Steam Guard requirements; do not assume the
  current username/password example is sufficient.
- Do not expose secrets in output, artifacts or generated manifests.
- Keep public Steam release manual and out of the initial scope.

### Merge protection proposal

After successful first runs and explicit user approval:

- Require PRs and passing quality, test, secret-scan and build statuses.
- Disallow force pushes to protected branches.
- Add review requirements when team development starts; single-developer
  review requirements can be lighter.
- Confirm ruleset/branch-protection configuration remotely before describing
  checks as mandatory.

### Defer for now

- SonarQube: the local AST gate already addresses the immediate size/complexity
  problem; avoid infrastructure without a concrete additional need.
- Automatic pixel-art regeneration on every PR.
- GPU/pixel-exact Godot rendering on an unvalidated hosted runner. Headless
  verification and GPU export checks are different kinds of evidence.
- Automatic Steam public deployment.

## First priority tomorrow: three concrete fixes

The user explicitly requested that tomorrow's repair work start with the
following three issues (2026-10-04). This supersedes the earlier CI-first
ordering. This session only documents the work; no implementation of these
three fixes is claimed.

### 1. Mixed responsibilities in player and game coordinator

- [PlayerComponent](../app/lib/game/components/player_component.dart) is 901
  lines and combines locomotion/physics, animation, plan execution, target
  selection, combat wiring and VFX.
- [TacticalModeGame](../app/lib/game/tactical_game.dart) is 700 lines.
  Its `onKeyEvent` is 136 lines with measured cyclomatic complexity 48.
- Extract coherent input, locomotion and plan-execution ownership incrementally.
  Start by inspecting callers and writing characterization tests for the
  selected responsibility; do not perform a wholesale rewrite or arbitrary
  line-count split.
- Preserve arrow movement, jump/flight/platform behavior, realtime/tactical
  actions, cancellation and restart semantics, fighter frame/facing sync and
  equipped appearance.
- Pass narrow state/contracts to extracted modules, not the entire game by
  default. Share action rules between realtime and tactical input.
- Acceptance: targeted behavior tests and full analyzer/tests pass; no import
  cycles or ratchet regressions; the player does not grow, and the extracted
  input flow has demonstrably simpler methods. Update ownership contracts and
  hash-bound >=700 capacity evidence rather than increasing baselines.

### 2. Global mutable character-sprite selection

- `PlayerComponent.characterSheetPath` is a mutable static field, changed
  directly by the character builder before requesting a reload.
- Replace this with player-instance-owned appearance selection and an explicit
  async selection operation. Preserve the immutable default atlas constant.
- Update every actual caller and test; do not leave a parallel global source
  of truth or introduce another mutable singleton.
- Validate/load before committing selection and appearance. Failed,
  cancelled or superseded loads must not replace a valid current appearance.
- Preserve the guard against selecting incompatible 32px sprites while
  fighter equipment is equipped.
- Acceptance: tests demonstrate independent selection for two player instances,
  failed selection retaining the old state, and deterministic handling of
  overlapping requests; existing fighter/equipment tests still pass.
- Coordinate with item 1 if atlas ownership is extracted, so these fixes do
  not create competing appearance controllers.

### 3. Inconsistent exporter success contract

- [Python stylizer](../tooling/stylize_blender_renders_to_pixelart.py) currently
  accepts an empty/missing input directory as a zero-PNG batch and reports
  `Wrote 0 ...` with successful exit.
- Reproduce this behavior first. Validate input directory, positive size and
  supported palette count before creating output or processing images.
- Missing/empty input, invalid parameters, unreadable images and failed output
  writes must produce an explicit diagnostic and nonzero exit; do not silently
  skip them or print a success summary.
- Preserve deterministic conversion and valid CLI usage/output placement.
  Avoid unrelated rendering changes or mandatory new infrastructure.
- Acceptance: focused CLI tests for missing/empty input, invalid parameters,
  corrupted PNG and output failure, plus a successful nonempty conversion with
  expected dimensions/transparency. Run the pinned Ruff profile.
- Document remaining partial-output behavior honestly; do not imply that a
  failed batch is atomic unless it actually uses transactional publication.

## Suggested next-session sequence

1. Inspect git status/branch and read the relevant contracts above.
2. Start the three approved repair priorities above, with characterization/
   failure tests and incremental changes. Complete and validate them before
   adding new gameplay systems or redesigning CI.
3. Then retrieve Actions runs for commit `69e6feb...`; inspect failed jobs/logs.
   Do not assume the locally passing checks passed remotely. Fix concrete CI
   failures before redesigning the pipeline.
4. Agree CI implementation scope with the user: consolidation first,
   release/deploy second, remote protection separately.
5. Inspect existing Steam manifests/tooling and repository PR templates before
   writing release/deploy logic or drafting a PR.
6. Consolidate checks and add PR Windows build plus concurrency/timeouts.
7. Validate workflows and scripts; run the relevant existing tests.
8. Implement a separate approved-artifact Steam deployment only when requested
   and necessary configuration/credentials are available.
9. Commit/push only with the applicable user authorization; report actual
   remote CI results and settings, not merely YAML presence.

## Local validation already completed

At the committed checkpoint:

- Full Flutter analysis: passed.
- Full Flutter tests: **79 passed**.
- Checker analysis: passed; checker suite: **20 passed**.
- Release web build: passed.
- Shared quality gate and changed-source formatting: passed.
- Architecture/data validators: passed.
- Ruff 0.12.12: passed.
- PSScriptAnalyzer 1.24.0: passed.
- ShellCheck 0.10.0: passed.
- Checked-process tests: **6 passed**.
- Godot headless verification: **28,957 checks, 0 failures**.
- Isolated staged-index verification: passed, including reference-source
  comparison and baseline-inflation rejection; real user staging unchanged.

These are **local results**, not evidence of a Windows release build, Steam
upload, GitHub CI success, or production readiness.

## Environment and implementation cautions

- Windows workspace: `C:\Users\mrsza\workspace\builds-and-bosses`.
- Local Flutter/Dart: `C:\src\flutter\bin\flutter.bat` / `dart.bat`.
- Workflow Flutter pin: `3.47.5`; app SDK requirement: `^3.13.4`.
  Verify compatibility on runners rather than assuming it.
- Local `core.hooksPath`: `.githooks`.
- Local `buildsAndBosses.dartPath`: `C:\src\flutter\bin\dart.bat`.
- The quality wrapper uses script-relative roots; direct Dart CLI defaults to
  running from `tooling\code_quality`, or accepts `--root`.
- Existing VS Code tasks have machine-specific Flutter paths.
- Godot/Aseprite executable defaults are Windows-specific but overridable.
- Prefer editor-aware Dart formatting; the previous session found that the
  formatting tool did not always persist edits to disk. Verify saved content,
  and do not overwrite conflicting unsaved user edits.
- Do not dump the generated baseline into agent context; inspect affected
  entries or use the report command.
- Production max: 800 physical lines; changed >=700 files require hash-bound
  ownership/capacity evidence. Legacy player is 901 lines, coordinator 700,
  character builder 740. There are 26 grandfathered over-threshold symbols.
- Reliability is improved, not universal: timed-out platform writes can finish
  later; process wrapper supervises a specific PID, not an entire process tree.
- The remaining Python stylizer can still report zero outputs as success;
  this was observed during the quality assessment, not fixed in the rollout.
  Do not claim all exporters have the same fresh-output/error contract.
