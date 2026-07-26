# Build / test / dev-loop performance audit

This document records the current Mobile CI performance pass status: what has
merged, what this PR adds, and which measured follow-up PRs are still open.

Numbers below come from GitHub Actions job or step durations. Estimates are
called out explicitly.

---

## Current merged state

As of this PR's merge base, the only performance PR from the pass that has
merged is [#6371](https://github.com/divinevideo/divine-mobile/pull/6371).

### Test backoff sleeps removed — #6371

Two upload-draft failure tests used the production retry backoff in wall-clock
time, sleeping `2 + 4 + 8 + 16 + 32 = 62s` per test. #6371 injects
`initialDelay: Duration.zero` for those tests while keeping the same retry count
and failure path.

Measured result:

| Path | Before | After | Delta |
|---|---:|---:|---:|
| Isolated upload-draft test file | 3m08s | 18s | -170s |
| Mobile CI `Tests` job | ~599s | ~500s | about -100s |

Recent successful `main` `Tests` job durations after #6371 were 412s, 483s,
499s, 545s, and 597s. The initial timing budget in this PR sets `Tests` at
`warn: 600` and `fail: 780`, which warns just above that observed range while
leaving runner variance below the hard fail threshold.

---

## This PR

This PR adds `.github/ci-timing-budgets.json` and
`mobile/scripts/ci/check_ci_timing_budget.py`, then runs the checker from the
terminal `mobile-ci` gate job. That gate starts after every upstream Mobile CI
job, so job durations are final when the checker runs.

The guard behavior is:

- Over `warn`: emit a GitHub warning annotation and keep the gate green.
- Over `fail`: fail the `mobile-ci` gate.
- Cannot measure: exit 2 and fail the gate instead of passing.
- Budgeted job missing or renamed: emit a notice so the missing measurement is
  visible in the gate log.

Budget keys match an exact job name or a matrix leg prefix. For example,
`Tests` covers both `Tests` and `Tests (shard 0/4)`, while `TestsExtra` is a
different job and does not inherit the `Tests` budget.

---

## Open measured follow-ups

These PRs are not shipped by this PR. If any of them merges and materially
changes Mobile CI timing, that PR should update `.github/ci-timing-budgets.json`
in the same change.

| PR | Status | Measured effect |
|---|---|---:|
| [#6372](https://github.com/divinevideo/divine-mobile/pull/6372) | Open | `Detect App CI Scope` 26s -> 4s; generated-files non-native path about -42s |
| [#6375](https://github.com/divinevideo/divine-mobile/pull/6375) | Open | `Tests` 599s -> 219s with four shards |
| [#6376](https://github.com/divinevideo/divine-mobile/pull/6376) | Open | Local 31-file subset 60s -> 17s via optimized test command |

The combined target if #6372 and #6375 both merge is roughly a 210s Mobile CI
critical path, with `Generated Files` becoming the next likely ceiling. That is
not the state this PR ships.

---

## Deliberately rejected during the pass

- Removing `flutter pub get` from `Format`: CI showed `dart format` depends on
  resolved analysis options through `very_good_analysis`.
- Deleting, skipping, or weakening tests: no ratchets, coverage floors, tags, or
  assertions were lowered to buy speed.
- Retiring `skip_very_good_optimization` tags as a drive-by: each tag encodes a
  test isolation requirement and needs a correctness fix in the owning test.
- Caching `build_runner` state inside generated-file verification: the job is a
  clean-generation proof, so caching needs its own correctness argument.
- Larger GitHub runners: potentially useful, but a cost decision rather than a
  code change.

---

## How to re-measure

```bash
# Per-job and per-step timing for one Mobile CI run.
python3 mobile/scripts/ci/report_mobile_ci_run.py --run-id <id>

# Local suite, matching current CI.
cd mobile
mise exec -- very_good test --optimization --concurrency=4 --exclude-tags integration
```
