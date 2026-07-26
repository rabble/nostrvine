# Test Performance

The app test suite is large enough that fixed startup costs and hidden waits
matter. Use `scripts/test_timing_baseline.sh` before and after test-speed
changes so improvements are measured instead of guessed.

## Running the suite locally

Use `mise run test` from `mobile/` for a full local run. It wraps the same
`very_good test --optimization --concurrency=4` command Mobile CI uses, so a
local pass means the same thing a CI pass does.

Plain `flutter test` compiles and spins a fresh isolate **per file**; the
optimizer bundles the untagged files into one. Measured head-to-head on an
identical subset (31 files / 277 tests, selected round-robin so it spans
directories, same machine, back to back):

| Command | Wall | Tests |
|---|---:|---:|
| `flutter test --concurrency=4` | 60s | 277 |
| `very_good test --optimization --concurrency=4` | 17s | 277 |

About 1.4s per file of isolate and compile overhead that the optimizer
amortises away. Keep using `flutter test <path>` while iterating on one
file — the optimizer has no subset flag, so it is all-or-nothing.

Note the optimized full suite can expose pre-existing seed- and load-sensitive
failures on a developer machine; #6372 tracks that cleanup. If a red run is not
obviously tied to your diff, capture the failing seed and rerun once before
root-causing against the merged-isolate state below.

## Baseline Commands

Run from `mobile/`:

```bash
scripts/test_timing_baseline.sh --quick
scripts/test_timing_baseline.sh --full
```

The script writes JSONL timing records to `/tmp` by default and stores command
logs in a temporary directory. Set `DIVINE_TEST_TIMING_OUTPUT` or pass
`--output` when a stable artifact path is needed.

## Merged-isolate state

Under `very_good test --optimization` the whole unit suite shares one isolate
and `flutter_test` auto-restores nothing between tests, so a process-global
mutation left un-restored strands later suites in a seed-dependent way. The
restore decision table and the shared-channel heal-and-blame harness are
documented in `.claude/rules/testing.md` (VGV merged isolate). Route shared
MethodChannel overrides through `overrideSharedChannel(...)`.

## Current Hotspots

- `test/flutter_test_config.dart` must keep ordinary test startup light. Golden
  setup is opt-in via `-D DIVINE_GOLDEN_TESTS=true`. Its root heal-and-blame
  tearDown only acts on a real shared-channel violation, so compliant tests pay
  nothing.
- `scripts/golden.sh` is the supported entrypoint for golden verification and
  update runs.
- `Future.delayed` and broad `pumpAndSettle()` calls should be replaced with
  explicit async coordination or bounded pumps when touching affected tests.
- `skip_very_good_optimization` tags should only remain when a test cannot be
  isolated safely under the VGV optimizer.

## Acceptance Signals

- App unit bucket wall time drops from the measured baseline.
- `scripts/check_future_delayed_ceiling.sh` and the VGV tag gate keep passing.
- Golden verification remains isolated to explicit golden paths.
- CI path filtering skips full app tests only when the app suite is not affected.
