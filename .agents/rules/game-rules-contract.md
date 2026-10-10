# Core Physics & Rules Coding Contract

When changing or adding code in `app/lib/core/physics/` or `app/lib/core/rules/`:

1. **Headless & Fixed-Point**: Pure Dart only. Zero Flame/Flutter, zero `double`, zero `DateTime.now`. Use `Fixed` milli-units (1000 = 1 tile, 200 = 1 foot).
2. **AST Limits**: Max 7 parameters per constructor/method (bundle larger sets into `<Name>Context` or `<Name>Breakdown`), max 80 lines per method, max nesting 4.
3. **Naming Ratchet**: Do NOT use Dart operator overloads (`+`, `-`, `<`, `==`). Use named methods (`add`, `sub`, `isLessThan`, `hasSameValue`). Private constructors must be `ClassName._internal(...)`, never `ClassName._(...)`.
4. **File Size**: Target 100–250 lines (🟢 Green Zone). Hard limit is 350 lines.
5. **Verification**: Always run `tooling/quick_check.ps1 -TestFile <path>` or `validate_quality.ps1` before completing tasks.
