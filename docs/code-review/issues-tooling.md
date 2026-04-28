# Tooling Issues

Issues related to linting, static analysis, and developer tooling.

Note: `very_good_analysis` is adopted across 33 packages with per-package CI, and pre-commit/pre-push hooks mirror CI locally. These 2 issues cover static analysis gaps: 38 suppressed lint rules (including type-safety rules like `invalid_assignment` that mask real bugs) and 3 packages with no `analysis_options.yaml`.

---

### 38 lint rules suppressed
**Problem**: `analysis_options.yaml` disables type-safety rules (`invalid_assignment`, `return_of_invalid_type`) and resource-leak rules (`cancel_subscriptions`, `unawaited_futures`).

**Evidence**: The app-level `analysis_options.yaml` disables 21 analyzer errors and 17 linter rules from `very_good_analysis`. Notable suppressions include: `invalid_assignment: ignore` and `return_of_invalid_type: ignore` (analyzer *errors*, not style preferences, which masks real type bugs), `avoid_catches_without_on_clauses: ignore` (allows bare `catch` blocks that suppress all exceptions), `unawaited_futures: ignore` (fire-and-forget async with no error handling), `avoid_dynamic_calls: false` (untyped method dispatch), `cancel_subscriptions: false` (stream subscriptions never cancelled, causing memory leaks), `only_throw_errors: ignore`, `depend_on_referenced_packages: false` (importing packages not in pubspec.yaml), `implementation_imports: false` (importing from `src/` of other packages, breaking encapsulation).

**Done well**: The project adopted `very_good_analysis` and 33 per-package workflows enforce it. The base commitment is right; the suppressions are the gap.

**Impact**: High. Type-safety rules (`invalid_assignment`, `return_of_invalid_type`) mask real bugs at compile time; `cancel_subscriptions` hides memory leaks; `unawaited_futures` hides fire-and-forget async with no error handling. These are safety rules, not style preferences. Suppressing analyzer errors reduces the benefit of adopting `very_good_analysis`.

**Effort**: Medium. Phased re-enablement required. Start with type-safety rules (`invalid_assignment`, `return_of_invalid_type`, `list_element_type_not_assignable`, `map_value_type_not_assignable`) as these likely indicate real bugs. Then address `unawaited_futures` and `cancel_subscriptions` for resource leak detection. Each rule re-enablement may surface existing violations that need fixing.

**GitHub ticket**: TBD

---

### 3 packages missing `analysis_options.yaml`
**Problem**: `follow_repository`, `keycast_flutter`, and `nostr_apps`. The app-level config excludes packages, so these may have zero static analysis.

**Evidence**: `follow_repository`, `keycast_flutter`, and `nostr_apps` do not have their own `analysis_options.yaml`. The app-level config excludes `**/packages/**` from analysis via its exclude list, meaning these three packages may have zero static analysis coverage: no lint rules, no type checks, no style enforcement.

**Impact**: Medium. Code in these packages gets no static analysis; bugs and style violations go undetected; new code can introduce issues that the linter would catch in any other package.

**Effort**: Low. Add `analysis_options.yaml` with `include: package:very_good_analysis/analysis_options.yaml` to each of the 3 packages. May surface existing violations that need fixing, but the configuration change itself is trivial.

**GitHub ticket**: TBD
