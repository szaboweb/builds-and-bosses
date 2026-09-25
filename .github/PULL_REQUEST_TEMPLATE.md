## Summary

<!-- What changed and why? -->

## Validation

- [ ] `tooling/validate_architecture.ps1`
- [ ] `tooling/validate_data.ps1`
- [ ] `flutter analyze`
- [ ] `flutter test`

## Architecture checklist

- [ ] Domain rules remain headless in `lib/core/`.
- [ ] Flame components only render/orchestrate results.
- [ ] UI widgets do not calculate combat, movement, dice, or inventory rules.
- [ ] New config/data fields have schema and tests.
- [ ] No secrets, credentials, tokens, or private keys are included.