# Build / test / dev-loop performance audit

Companion to [`PERF_BASELINE.md`](PERF_BASELINE.md), which records the "before"
numbers and how they were taken. This document records what was changed, what
it actually bought, what was deliberately **not** done, and what is left.

Every number below was measured. Nothing here is an estimate unless it says so.

---

## Headline

| | Before (p50) | After | Δ |
|---|---:|---:|---:|
| **Mobile CI critical path** | **625s** | **~223s** | **−64%** |
| `Tests` job | 599s | 219s | −380s |
| `Run Flutter tests` step | 558s | 159s (slowest shard) | −399s |
| `Detect App CI Scope` | 26s | 4s | −22s |
| `Generated Files` (non-native PR) | 198s | ~156s | −42s |
| Full local suite (`flutter test` → optimized) | 60s / 31 files | 17s / 31 files | −72% |

The critical path is `Detect App CI Scope → Tests`, because every other Mobile
CI job declares `needs: changes` and runs in parallel underneath. `223s` is
`4s + 219s`; with the backoff fix also merged the slowest shard drops further
(see [Interaction between the changes](#interaction-between-the-changes)).

---

## What shipped

### 1. CI config — [#6372](https://github.com/divinevideo/divine-mobile/pull/6372)

**`Detect App CI Scope` stopped cloning the repo. 26s → 4s.**

The job ran `git diff --name-only` between two SHAs and paid
`actions/checkout@v4` with `fetch-depth: 0` for the privilege — 23s of the 26s,
for a step that then took 0s. The REST API already has the changed-file list, so
the job now runs with no checkout at all. It falls open to the full matrix above
the endpoint's 3000-file cap rather than acting on a truncated list.

**The transport-security guard is gated on native changes. ~42s saved on most PRs.**

`check_native_transport_security.sh` reads one Android XML and three
`Info.plist` files. If none changed, its verdict is identical to the one `main`
already recorded. 42 of the step's 43 seconds were `apt-get update` (28s) plus
installing `libxml2-utils` (14s) — `xmllint` is genuinely absent from the
`ubuntu-24.04` image. The guard still runs in full on `main`, on non-PR events,
and on any PR touching native config or the script.

### 2. Test speed — [#6371](https://github.com/divinevideo/divine-mobile/pull/6371)

**Two tests were sleeping 62 seconds each. `Run Flutter tests` 558s → 435s.**

Per-test durations recovered from the CI log showed the ten slowest tests owning
35% of the suite, and two of them costing 62s apiece. Both drive `UploadManager`
to retry exhaustion, and `UploadRetryPolicy` sleeps its backoff in wall-clock
time: `2 + 4 + 8 + 16 + 32 = 62s`, twice.

Injecting `initialDelay: Duration.zero` removed the sleeping. `maxRetries` stays
at the production default, so exhaustion still takes the same six attempts
through the same code; the backoff arithmetic keeps its own coverage in
`upload_retry_policy_test.dart`. Isolated file: **3m08s → 18s**. Predicted CI
saving 124s, measured 123s.

### 3. Test sharding — [#6375](https://github.com/divinevideo/divine-mobile/pull/6375)

**`Tests` 599s → 219s.**

`very_good test --optimization` collapses every untagged test file into a single
`.test_optimizer.dart` suite — one process. Once the 18
`skip_very_good_optimization` files finish, `--concurrency=4` has nothing left
to schedule and the bulk of the run is **one core of a four-vCPU runner**.

`very_good` has no subset flag, so each of four matrix legs reduces `test/` to
its own slice (round-robin over the sorted file list) before `very_good` scans
it. Only `*_test.dart` entry points are removed; helpers, mocks, fixtures and
`flutter_test_config.dart` stay.

| Leg | Job | Test step |
|---|---:|---:|
| shard 0/4 | 202s | 143s |
| shard 1/4 | **219s** | 159s |
| shard 2/4 | 163s | 110s |
| shard 3/4 | 210s | 150s |

Shard-selection itself costs 1s. The four shards reported 3247 + 3090 + 3129 +
3699 = **13,165 tests**, exactly the suite's 13,159 plus the 6 tests the PR
adds — verified at runtime that nothing is dropped and nothing runs twice.

### 4. Dev loop — [#6376](https://github.com/divinevideo/divine-mobile/pull/6376)

**`mise run test` runs the suite the way CI does. 3.5× faster than `flutter test`.**

`CONTRIBUTING.md` told developers to run `flutter test`, which compiles and
spins a fresh isolate per file. Measured head-to-head on an identical 31-file /
277-test subset, same machine, back to back: **60s plain, 17s optimized** —
about 1.4s per file of overhead the optimizer amortises away.

### 5. Regression guard — this PR

Budgets in `.github/ci-timing-budgets.json`, checked by the `mobile-ci` gate
job, which only starts once every other job has finished. Over the `warn`
threshold annotates the PR; over `fail` fails the gate. The checker exits 2 —
never 0 — when it *cannot* check (unreadable budget file, empty job payload,
`warn` above `fail`), and reports rather than silently passing a budgeted job
that did not run, so a rename cannot quietly drop a job out of the budget.

---

## Interaction between the changes

#6371 and #6375 both touch the test step, and their savings are **not** additive
in the obvious way. `upload_manager_from_draft_test.dart` sorts to index 755 of
1226, so under a 4-way round-robin its whole 124s lands in **shard 3** alone.
Shard 3's measured 150s test step therefore contains that 124s; with #6371 also
merged it should fall to roughly 30s, and the slowest leg becomes shard 1 at
~159s.

Expected combined critical path once all three CI PRs are in: **~4s + ~205s ≈
210s**, against a 625s baseline. `Generated Files` (~156s after #6372) then sits
just below `Tests` as the next ceiling.

---

## Deliberately rejected

Speed was never bought with correctness. Things that would have been faster and
were not done:

- **Removing `flutter pub get` from the `Format` job.** Attempted in #6372 on
  the theory that `dart format` is purely syntactic. CI proved otherwise: the
  formatter reads its page width from `analysis_options.yaml`, which `include`s
  `package:very_good_analysis`, and with no resolved package config it falls
  back to defaults and reports 529 changed files. Reverted in the same PR; the
  failure is left in the branch history rather than force-pushed away.
- **Deleting, skipping, or weakening any test.** Every ratchet
  (`untested_services`, `test_unit_structure`, the four design-system ceilings,
  `skip_very_good_optimization` tag gate, shared-channel and package-channel
  isolation) is untouched. No `@Skip`, no lowered `min_coverage`, no removed
  assertion, no `--no-verify`.
- **Loosening the 62s backoff tests instead of speeding them.** Both were
  verified to still go red when the retry-exhaustion `rethrow` is removed from
  `UploadRetryPolicy`, then restored.
- **Retiring `skip_very_good_optimization` tags to shrink the tagged set.** Each
  tag encodes a real isolation requirement (native channel handlers,
  `HttpOverrides.global`, on-disk sqlite). Untagging is a correctness change per
  file, not a perf change, and belongs with whoever fixes the underlying
  isolation.
- **Caching `build_runner` state across CI runs.** The 101s codegen verification
  in `Generated Files` is the largest remaining single step. `build_runner`
  hashes its own inputs so a cache would likely be safe, but that job's entire
  purpose is to prove generated files are up to date from a clean graph — a
  cache in the middle of a correctness proof needs its own justification and
  measurement, not a drive-by.
- **Larger GitHub runners.** Would help; costs money on the Team plan. That is
  a budget decision, not an engineering one.
- **Path-filtering the package workflows.** Checked, not needed — all 57 already
  carry `paths:` filters scoped to their own package. The six workflows without
  filters are intentionally repo-wide. No waste to recover.
- **Dropping `--coverage` where it isn't consumed.** Checked: `Mobile CI` does
  not collect it, and the package workflows that do also gate on it.

---

## Also found, not a perf issue

**The optimized full suite is not reliably green run-to-run on a developer
machine — on `main` as well as on branches.** Across seven local runs at a fixed
seed, a `main`-equivalent run failed on `personalEventCacheServiceProvider keeps
queued events through transient non-auth states` (the known CI-only flake,
#6280); other runs failed on `clips_library_bloc_test.dart` and
`video_event_service_deduplication_test.dart`. Each failing test passes in
isolation, and CI was green throughout.

This cost real time during this work: two red local runs on a branch looked like
a regression until an interleaved A/B — same worktree, only the one changed line
toggled — showed the *unfixed* arm failing too. Recorded in `PERF_BASELINE.md`
so the next person re-runs before attributing a red local suite to their diff.

---

## Left on the table

Ordered by (estimated seconds × frequency) ÷ risk.

| Opportunity | Estimated | Notes |
|---|---:|---|
| `build_runner` state cache in `Generated Files` | ~70s/run | Now the critical path once sharding lands. Needs its own correctness argument (see above). |
| Balance shards by measured cost, not file count | ~30–50s/run | Legs ran 110–159s on CI, 83–215s locally. A committed per-file timing baseline would even them out, at the cost of a baseline that drifts. |
| More shards (6 or 8) | diminishing | Each leg pays ~45s of fixed setup, so past ~4 the setup cost eats the gain. Worth revisiting only after the balance fix. |
| Cache `dart pub global activate very_good_cli` | 9s × 4 legs | Small, and sharding multiplied it by four. |
| The next tier of slow tests | ~40s | After the two 62s tests, the next band is seven tests at 6.6s each. Same shape (real waits), much smaller prize. |
| `flutter analyze` at 71s | — | Needs whole-project context; scoping it to changed files would trade coverage for speed. Not worth it. |

---

## How to re-measure

```bash
# Per-job p50/p90 across recent runs, and per-step for one run
python3 mobile/scripts/ci/report_mobile_ci_run.py --run-id <id>

# The local suite, exactly as CI runs it
cd mobile && mise run test

# Plain vs optimized on an identical subset
cd mobile
bash scripts/ci/select_test_shard.sh --total 40 --index 0 --force
mise exec -- flutter test --concurrency=4 --exclude-tags integration
mise exec -- very_good test --optimization --concurrency=4 --exclude-tags integration
git checkout -- test
```
