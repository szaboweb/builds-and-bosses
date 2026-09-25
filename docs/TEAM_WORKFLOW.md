# Team Workflow

The repository is prepared for a two-branch workflow, but branch protection remains intentionally inactive while development is single-person.

## Branches

- `main`: releasable branch.
- `dev`: integration branch for features and fixes.
- `feature/<short-name>`: focused work branches created from `dev`.
- `fix/<short-name>`: focused bug-fix branches created from `dev`.

## Intended flow

```text
feature/* or fix/* -> Pull Request -> dev -> Pull Request -> main
```

When team development begins, enable these repository settings:

1. Protect `main` and require pull requests.
2. Require at least one approving review.
3. Dismiss stale approvals after new commits.
4. Require the `windows-build` and `secret-scan` checks.
5. Require the architecture/data validation checks.
6. Restrict direct pushes to `main`.
7. Optionally protect `dev` with CI required but allow maintainer integration.

`CODEOWNERS` is already present, but enforcement is intentionally disabled until these settings are activated in GitHub repository settings.

## Current single-developer mode

Until protection is enabled, use `dev` for active work and merge to `main` when a stable checkpoint is ready. The same PR template and checks should still be used locally to keep the future workflow honest.