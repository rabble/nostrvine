# Test Performance

The app test suite is large enough that fixed startup costs and hidden waits
matter. Use `scripts/test_timing_baseline.sh` before and after test-speed
changes so improvements are measured instead of guessed.

## Baseline Commands

Run from `mobile/`:

```bash
scripts/test_timing_baseline.sh --quick
scripts/test_timing_baseline.sh --full
```

The script writes JSONL timing records to `/tmp` by default and stores command
logs in a temporary directory. Set `DIVINE_TEST_TIMING_OUTPUT` or pass
`--output` when a stable artifact path is needed.

## Current Hotspots

- `test/flutter_test_config.dart` must keep ordinary test startup light. Golden
  setup is opt-in via `-D DIVINE_GOLDEN_TESTS=true`.
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
