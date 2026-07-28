# CI Timing-Budget Shard Coverage Fix

## Problem

The timing-budget checker deliberately lets a base budget such as `Tests`
cover matrix jobs named `Tests (shard 0/4)`. After the test-sharding and
timing-budget pull requests merged, the budget-file self-test rejected that
valid prefix relationship because it required every workflow job name to be an
exact key in `.github/ci-timing-budgets.json`.

## Design

Keep the existing workflow names and the single `Tests` budget. Change the
budget-file coverage assertion to use the checker's established matching rule:
a budget covers a job when the names are equal or the job name starts with the
budget name followed by ` (`. This preserves the guard against unrelated names
such as `Tests Extra`.

The change is limited to the CI timing-budget test. Production checker behavior,
workflow structure, and threshold values remain unchanged.

## Verification

Use the current failing focused test as the regression case:

```bash
cd mobile
flutter test test/tools/check_ci_timing_budget_test.dart
```

Then run formatting and analysis for the touched test and rely on the pull
request's full Mobile CI matrix to verify the combined `main` configuration.

## Outcome

Shipped on `main` via #6409: the assertion learned the prefix rule, plus an
end-to-end test that drives the committed budget file through the real script
with a rendered shard name, so a self-consistent but dead budget key fails
instead of passing.
