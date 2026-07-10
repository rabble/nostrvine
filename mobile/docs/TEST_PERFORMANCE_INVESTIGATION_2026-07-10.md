# Test Performance Investigation — 2026-07-10

## Executive summary

Divine already has a strong foundation: a randomized optimized app suite,
package-specific coverage floors, test-debt ratchets, isolated golden and service
integration lanes, and path filtering for package-only and docs-only changes.
The main problem is no longer “Flutter tests are inherently slow.” It is that a
small number of tests pay real production retry schedules, while the local
developer workflow often pays Flutter startup once per file.

The clearest confirmed wins are:

1. **Stop one draft-upload test from sleeping through the production retry
   policy.** Its file has a repeatable 67.80-second median. Injecting the already
   supported zero-retry `UploadRetryConfig` preserves all assertions and cuts
   the median to 5.78 seconds, a 91.5% reduction. Because this file is in the
   optimizer's merged suite, this should remove about 62 seconds from the full
   app lane as well.
2. **Batch locally affected files into one Flutter invocation.** Five
   representative files take about 17.77 seconds when invoked separately but
   4.42 seconds together, a 75.1% reduction with identical test coverage.
3. **Make retry/backoff time injectable in `VideoEventPublisher`.** Two publish
   rejection tests each spend about 6.6–6.7 seconds in the real 2s + 4s
   backoff. Their contracts concern publish outcomes, not wall-clock waiting.
4. **Fix random-order isolation before increasing concurrency.** The current
   welcome-screen suite fails reproducibly with seed `424242` because a
   600-pixel-tall surface overflows when the affected test runs first. A cache
   provider assertion also failed once under the 16-process profiler but passed
   three isolated repetitions; it needs focused race diagnosis before being
   used as evidence for or against higher concurrency.
5. **Use a layered feedback loop.** Developers should run all affected files in
   one command, run package coverage at the pre-push boundary rather than on
   every edit, and retain the complete randomized optimized suite in CI.

Recent successful full-app CI has a p50 wall time of 8m58s and p95 of 9m20s.
The Tests job is the critical path: p50 8m27s, including p50 7m31s of test
execution. The generated-files, format, and analyze jobs finish much earlier.
Optimizing CI setup alone cannot materially change wall time.

No coverage floor, skip ceiling, optimizer isolation rule, or random-order gate
should be weakened. The fastest route is to remove accidental waiting and
duplicated process startup while keeping the behavioral safety net.

## Scope and method

The investigation ran from commit `8464bf6d7703e750009f5f609cf4819a012a9b64`,
which was fresh `origin/main` when the worktree was created.

Local environment:

- macOS 26.5.1 on Apple M4 Max
- 16 logical CPUs and 48 GiB RAM
- Flutter 3.44.2 / Dart 3.12.2
- CI is pinned to Flutter 3.44.0, so local-to-CI comparisons are directional;
  CI percentiles remain the authoritative hosted-runner evidence.

Measurements included:

- supported quick and full timing-baseline buckets;
- first and warm targeted files from BLoC, repository, service, widget, router,
  and golden layers;
- the exact optimized CI test command with Very Good CLI 1.3.0;
- an unoptimized 16-process JSON-reporter run for per-file attribution;
- package tests with and without coverage;
- 60 recent Mobile CI PR workflow outcomes and job/step detail for 23 recent
  successful full-app runs;
- static indicators across all app test files;
- a stratified usefulness review and three controlled mutations;
- three reversible performance experiments.

All timing artifacts were written outside the repository. The profiler run used
a fixed seed (`424242`) for reproducibility. The normal CI lane intentionally
continues to use a random seed.

## Test inventory and existing gates

| Surface | Test files |
| --- | ---: |
| App (`mobile/test`) | 1,175 |
| Packages (`mobile/packages/*/test`) | 355 |
| Integration (`mobile/integration_test`) | 33 |

The app suite contains 11,962 runnable cases under the current non-integration
selection and 317 skipped cases. The JSON profiler loaded 1,172 suites; the
three golden files use the supported golden entrypoint rather than the normal
app profiler.

Existing guardrails all reconciled against `origin/main`:

- 16 files opt out of Very Good merged-isolate optimization, exactly matching
  `test/vgv_tag_baseline.txt`;
- 77 app test files are in the skip-file baseline, and the measured suite
  contains 317 skipped cases;
- 816 `Future.delayed` calls occur across 143 app test files;
- 1,987 `pumpAndSettle` calls occur across 253 app test files;
- 51 package coverage floors are locked and may only rise: 24 are 100%, one is
  0% (`video_event_cache`), and the mean floor is 80.5%;
- 48 non-comment entries remain in the same-name untested-services baseline.
  This is an existence ratchet, not a claim that those services have no tests;
  several large services have behavior split across multiple focused files.

The counts above are triage inputs, not automatic defects. A zero-duration
`Future.delayed`, a bounded `pumpAndSettle`, or a focused equality test may be
correct. Each candidate still needs a failing behavior and measured cost.

## Local feedback-loop baseline

### Supported buckets

| Bucket | Wall time | Result |
| --- | ---: | --- |
| App unit | 17s | pass, 13 skipped |
| App router | 14s | pass |
| App goldens | 5s | pass |
| App services | 117s | pass |
| App widgets | 90s | pass |
| `models` package from app root | 10s | pass |
| `db_client` package from app root | 14s | pass |

The first unit-bucket invocation after dependency setup took 33.64 seconds;
warm invocations took 17 seconds. Dependency resolution itself took 5.3
seconds and is not included in the test times.

The supported `--full` timing script initially reported the optimized bucket as
an immediate failure because Very Good CLI was not installed locally. After
installing the same pinned 1.3.0 version used by CI, the bucket passed. The
environmental failure is useful developer-experience evidence: the timing
script assumes the CLI is already installed and on `PATH`.

### Representative targeted files

| Layer | First measured | Warm median | Warm range |
| --- | ---: | ---: | ---: |
| BLoC | 4.06s | 3.42s | 3.42–3.53s |
| Repository | 3.44s | 3.37s | 3.36–3.49s |
| Service | 3.53s | 3.38s | 3.34–3.42s |
| Widget | 4.15s | 4.10s | 3.97–4.14s |
| Router | 3.48s | 3.50s | 3.44–3.50s |
| Golden | 14.43s | 4.18s | 3.99–4.99s |

The near-identical warm floor across logic and UI layers is strong evidence that
Flutter process/load cost dominates small targeted files.

### Optimized versus unoptimized app suite

| Command shape | Wall | User + system CPU | Result |
| --- | ---: | ---: | --- |
| Very Good optimized, concurrency 4 | 335.38s | 256.28s | 11,962 passed; 317 skipped |
| Flutter unoptimized, concurrency 16 | 405.50s | 1,402.78s | 11,960 passed; 317 skipped; 2 failed |

Despite using four times as many processes, the unoptimized profiler was 17.3%
slower in wall time and consumed 5.47 times as much recorded CPU time. The
optimizer therefore remains valuable: it reduces recorded CPU by 81.7% and
avoids thousands of repeated suite loads.

The per-suite profiler supports the same conclusion:

- median suite load: 3.943s;
- median behavioral execution: 0.138s;
- load exceeded behavioral execution in 1,150 of 1,172 suites (98.1%);
- 561 suites performed less than 100ms of behavioral execution;
- summed per-suite elapsed time was 5,554s loading versus 755s executing.

Those sums overlap because 16 processes ran concurrently and should not be read
as wall time. They are useful for identifying the source of repeated work.

### Package coverage cost

The `models` package warm median was 6.48 seconds without coverage and 8.79
seconds with coverage, a 35.6% increase. Coverage is affordable at pre-push and
CI boundaries, but paying it after every edit is unnecessary when the developer
needs the fastest first failure.

## Slowest files and tests

The table is from the 16-process JSON profiler. `load` includes compilation and
suite initialization under host contention; `test` is elapsed time attributed
after the loading pseudo-test. Only the 62.7-second retry case was independently
reproduced with repeated single-file measurements, so the remaining rankings
are candidates for focused confirmation rather than proof of causality.

| Rank | File | Wall | Load | Test |
| ---: | --- | ---: | ---: | ---: |
| 1 | `test/services/upload_manager_from_draft_test.dart` | 69.922s | 4.665s | 65.246s |
| 2 | `test/services/video_event_publisher_publish_confirmation_test.dart` | 19.920s | 3.436s | 16.474s |
| 3 | `test/blocs/user_search/user_search_bloc_test.dart` | 18.059s | 5.430s | 12.562s |
| 4 | `test/services/cache_first_query_test.dart` | 16.422s | 14.950s | 1.469s |
| 5 | `test/blocs/profile_editor/profile_editor_bloc_test.dart` | 16.414s | 3.590s | 12.625s |
| 6 | `test/services/auto_draft_complete_flow_test.dart` | 16.068s | 15.942s | 0.126s |
| 7 | `test/services/content_reporting_service_test.dart` | 15.779s | 15.545s | 0.224s |
| 8 | `test/services/crosspost_api_client_test.dart` | 15.482s | 15.445s | 0.029s |
| 9 | `test/services/auth_service_timestamp_test.dart` | 15.286s | 15.272s | 0.014s |
| 10 | `test/services/video_event_publisher_native_proof_test.dart` | 15.284s | 1.998s | 13.279s |
| 11 | `test/blocs/fullscreen_feed/fullscreen_feed_bloc_test.dart` | 15.262s | 6.743s | 8.474s |
| 12 | `test/services/content_filter_service_test.dart` | 15.198s | 15.129s | 0.068s |
| 13 | `test/services/video_event_publisher_embedded_thumbnail_test.dart` | 15.137s | 14.467s | 0.667s |
| 14 | `test/services/profile_editing_test.dart` | 15.033s | 14.824s | 0.197s |
| 15 | `test/services/nip07_types_test.dart` | 14.993s | 14.954s | 0.027s |
| 16 | `test/services/upload_publishability_test.dart` | 14.887s | 14.873s | 0.014s |
| 17 | `test/services/subscription_manager_cache_test.dart` | 14.692s | 14.664s | 0.017s |
| 18 | `test/services/collaborator_response_service_test.dart` | 14.666s | 14.524s | 0.028s |
| 19 | `test/services/proofmode_frame_capture_test.dart` | 14.635s | 14.626s | 0.009s |
| 20 | `test/services/nostr_service_factory_test.dart` | 14.592s | 14.571s | 0.019s |

The highest measured individual tests were:

| Test | Profiled duration | Evidence |
| --- | ---: | --- |
| Draft upload throws after failed upload | 62.728s | Confirmed production retry schedule; repeated file median 67.80s |
| Publish does not mark relay rejection as published | 6.710s | Production 2s + 4s retry backoff is reachable |
| Publish returns false after all relay rejections | 6.619s | Production 2s + 4s retry backoff is reachable |
| Native ProofMode tags are published | 6.662s | Needs isolated remeasurement; profiler contention may dominate |
| Native ProofMode field-name variants survive | 6.617s | Needs isolated remeasurement; profiler contention may dominate |

Several widget cases also appeared between 5.5 and 6.8 seconds, but they do not
contain matching waits. That pattern, plus their suite-level loading costs,
suggests host contention during the 16-process profiler rather than a confirmed
per-test delay.

## Root causes

### 1. Production retry schedules leak into tests

`UploadRetryConfig` defaults to five retries with 2-second exponential backoff.
The draft-upload failure test constructs `UploadManager` with that production
default even though it asserts only that a failed upload throws and is persisted
as failed. The observed 62.7-second test duration matches 2 + 4 + 8 + 16 + 32
seconds of backoff.

`VideoEventPublisher` hard-codes three attempts and real 2s/4s waits. Publish
confirmation tests that need to observe multiple attempts must therefore wait
six seconds each. Unlike `UploadManager`, the publisher has no injected retry
policy or delay function.

### 2. Local commands duplicate process startup

Running five representative files separately costs about 17.77 seconds using
their warm medians. Passing the same five paths to one `flutter test` command
takes a 4.42-second median. Flutter already accepts multiple paths; no custom
test orchestrator is required to capture this win.

### 3. Optimizer opt-outs still pay separate startup

The 16 opt-out files took:

| Concurrency | Wall |
| ---: | ---: |
| 1 | 27.28s |
| 4 | 12.98s |
| 8 | 10.36s |

On the 16-core local machine, moving from 4 to 8 saved only 2.62 seconds for
this lane. CI has four vCPUs, so this is not evidence for raising CI concurrency.
It is evidence that removing safe opt-outs is more durable than consuming more
cores.

### 4. Random-order isolation is incomplete

The unoptimized profiler found two failures:

- `welcome_screen_test.dart` overflowed by 17 pixels when “does not show error
  when lastError is null” ran first under seed `424242`. The file passed in
  declaration order but failed three of three isolated fixed-seed repetitions.
  Neighboring tests explicitly use an 800×1200 surface; the affected test relies
  on the default 800×600 surface. This is a reproducible order-dependent layout
  assumption.
- `personal_event_cache_service_provider_test.dart` failed once under the
  16-process full profiler but passed three of three isolated fixed-seed runs.
  This is evidence of a possible host-resource or async race, not enough
  evidence to assign a root cause.

Recent CI also shows test failures are not hypothetical: among 60 recent Mobile
CI PR outcomes, 56 succeeded and four failed. Three failures included the Tests
job; the fourth failed a layering guard. No failed run had a same-SHA successful
rerun in the 100-run API sample, so a defensible flake rate cannot be derived.
The workflow should preserve the random seed and failure signature as a
first-class artifact before labeling any failure flaky.

### 5. CI reporting still assumes an obsolete shard matrix

`mobile/scripts/ci/report_mobile_ci_run.py` selects every job whose name starts
with `Tests` and prints longest/shortest shard statistics. The current workflow
has one `Tests` job, so it reports that job as both longest and shortest with a
zero spread. The script should report the Tests step, setup share, and critical
path instead of a meaningless shard summary.

## CI critical path

The dataset is the 23 most recent successful full-app PR runs among the latest
25 successful Mobile CI runs. Two successful runs were docs-only and correctly
skipped the app jobs.

| Metric | Min | p50 | p95 | Max |
| --- | ---: | ---: | ---: | ---: |
| Workflow wall | 8m00s | 8m58s | 9m20s | 9m40s |
| Tests job | 7m25s | 8m27s | 8m45s | 9m03s |
| Test execution step | 6m37s | 7m31s | 7m58s | 8m09s |
| Tests setup | 37s | 46s | 53s | 54s |
| Generated Files job | 2m34s | 2m51s | 3m03s | 3m06s |
| Analyze job | 1m27s | 1m44s | 1m59s | 2m03s |
| Format job | 43s | 53s | 1m10s | 1m31s |

Across the parallel Mobile CI jobs, p50 summed compute is 14m26s. Repeated
checkout/Flutter/dependency/CLI setup accounts for p50 2m37s of compute, while
four `flutter pub get` steps account for only 35 seconds. Because those jobs run
in parallel, collapsing them would save compute at the risk of increasing wall
time. The Tests job is the current wall-clock target.

The draft-upload experiment alone would move the p50 test-execution step from
about 451 seconds toward 389 seconds if the saving remains additive on CI, as
expected for a test inside the merged sequential suite. That is an estimated
13.7% test-step improvement and 11.5% workflow improvement without deleting or
skipping a test.

The service integration workflow is manual and has no recorded Actions runs.
Local measurement could not start because the Docker daemon was not running.
No service-integration duration is claimed from this investigation.

## Coverage usefulness

### Product-risk map

Path-name matching found broad test presence across the major risk areas. These
counts measure discoverable files, not semantic completeness:

| Risk area | Matching test files | Representative protection |
| --- | ---: | --- |
| Authentication and key management | 99 | auth journeys, key export, multi-account switching, Keycast/Nostr key packages |
| Nostr construction/signing/publishing/parsing | 114 | NIP-71 kinds, signed publish confirmation, NIP-17, event DAOs |
| Feed/pagination/cache/dead media | 180 | feed BLoCs, cache packages, TTFF integration, pagination and dead-media behavior |
| Recording/editing/upload/publish | 230 | camera integration, editor BLoCs/widgets, background uploader, publish services |
| Draft persistence | 21 | draft DAO, copy/persistence, auto-draft, library BLoC |
| DM/privacy/moderation/minor safety | 95 | NIP-17, message requests, metadata stripping, moderation and protected-minor flows |
| Routing/account transitions | 49 | redirect rules, shell navigation, account-state and splash release |
| Database/migration/serialization | 147 | Drift migrations, DAOs, models and serialization |
| Repository/client recovery | 166 | package repositories, retry, timeout, fallback and recovery tests |

The important gap is not a lack of test files. It is whether critical tests run,
fail for the intended regression, and execute at the cheapest valid layer.

### Controlled mutation evidence

Three critical behaviors were deliberately broken one at a time and restored:

| Behavior | Mutation | Expected red evidence |
| --- | --- | --- |
| Protected-minor fail-safe | Missing/empty token mapped to `notProtected` instead of `unknown` | Two repository cases failed on exact status mismatch |
| Nostr 32-byte identifier validation | Validator changed from 64 to 63 hex characters | Both valid and invalid boundary cases failed |
| Trending hashtag callback | Callback received `mutated` instead of selected hashtag | Widget interaction failed with expected `funny`, actual `mutated` |

These are useful tests: each caught a plausible regression at an appropriate
boundary and failed for the claimed reason.

### Coverage-theatre candidates

A name-based scan found at least:

- 10 instantiation-only cases;
- 11 styling/property-worded cases;
- 125 equality/`props` cases;
- 89 renders-only cases.

These are review candidates, not a deletion list. Sampling found concrete weak
examples:

- `TrendingHashtagsSection hashtag chips have correct styling` only asserts
  that some ancestor `Container` exists. It would remain green if the chip's
  color, radius, or padding broke, so it cannot catch its claimed regression.
- `VideoMetadataPreviewScreen can be instantiated` asserts that constructing a
  widget returns that widget type. Compilation already provides almost all of
  that evidence, while the adjacent render/interaction tests carry behavior.
- `BackgroundBlocUpload can be instantiated` asserts non-null construction and
  duplicates evidence from the subsequent BLoC behavior tests.
- `OriginalContentBadge renders with correct styling` checks visible text and
  icon but no styling. The assertions may still protect content, but the name
  overstates the contract and invites mistaken confidence.

Equality tests deserve selective retention. A state/event `props` regression
can suppress BLoC emissions and is behaviorally important; duplicated equality,
inequality, props, default, and constructor cases for the same type may not each
add a distinct failure mode.

## Experiments

| Experiment | Before | After | Change | Result |
| --- | ---: | ---: | ---: | --- |
| Inject zero retries in draft-upload flow test | 67.80s median | 5.78s median | −91.5% | All five file tests pass; all assertions preserved |
| Batch five affected files in one Flutter command | ~17.77s summed warm medians | 4.42s median | −75.1% | Same five files and cases pass |
| Opt-out runner concurrency 1 → 4 → 8 | 27.28s | 12.98s → 10.36s | −52.4%, then −20.2% | Diminishing local return; no basis to exceed CI's four vCPUs |

All experimental source changes were restored before the report was written.

## Approaches considered

### A. Runner and CI tuning only

Keep the test architecture unchanged and tune concurrency, caching, setup, and
sharding.

**Benefit:** low source-code churn. **Limit:** the existing optimizer already
removes 81.7% of recorded CPU versus the unoptimized profiler. Higher
concurrency affects only separate suites/opt-outs and cannot remove a
62-second real retry inside the merged suite. Setup work is parallel and is not
the critical path.

### B. Test architecture cleanup only

Move logic to pure Dart/BLoC/repository layers, inject clocks/retry policies,
remove redundant coverage theatre, and repair global-state isolation.

**Benefit:** best long-term speed and signal quality. **Limit:** broad rewrites
are slower to review, can accidentally delete protection, and provide no
immediate help when developers invoke files one at a time.

### C. Layered feedback plus focused architecture cleanup — recommended

Batch affected tests locally, keep plain package tests in the edit loop, keep
coverage and randomized complete suites at pre-push/CI boundaries, and remove
confirmed real-time waits one focused PR at a time.

This combines the immediate 75% local batching win with the highest-confidence
suite reductions, without inventing a complex test selector or weakening merge
gates.

## Recommended feedback lanes

### Immediate edit loop

Run all known affected files in one invocation:

```bash
cd mobile
flutter test \
  test/path/first_test.dart \
  test/path/second_test.dart \
  --no-pub --reporter=compact
```

For a single file:

```bash
flutter test test/path/feature_test.dart --no-pub --reporter=compact
```

### Package edit loop

```bash
cd mobile/packages/<package>
flutter test --no-pub --reporter=compact
```

Before pushing a package change, use its enforced coverage lane:

```bash
flutter test --coverage --no-pub
```

For `videos_repository`, retain the repository-specific full coverage command
required by `AGENTS.md`.

### Visual lane

```bash
cd mobile
scripts/golden.sh verify test/goldens/widgets/<widget>_golden_test.dart
```

Use the full golden verification command when the visual change is broad.

### Pre-push app lane

Run affected tests first, then analysis. For cross-cutting app changes or before
final handoff, run the CI-equivalent suite:

```bash
cd mobile
very_good test \
  --optimization \
  --concurrency=4 \
  --exclude-tags integration \
  --test-randomize-ordering-seed random
flutter analyze lib test integration_test
```

Very Good CLI must remain pinned consistently with CI.

### Service integration lane

With Docker running:

```bash
cd local_stack
docker compose up -d
cd ../mobile
flutter test integration_test/e2e/ --tags service
cd ../local_stack
docker compose down
```

This specialized lane should not block every edit, but it needs scheduled or
change-triggered execution so zero workflow history does not become permanent
coverage debt.

## Phased implementation plan

### Phase 1: remove confirmed waste and restore deterministic evidence

1. Configure `upload_manager_from_draft_test.dart` with zero retries and rerun
   the file plus the complete optimized suite. This is a small test-only PR with
   an expected roughly one-minute suite reduction.
2. Fix `welcome_screen_test.dart` so every layout-sensitive case establishes
   and restores its own surface size. Prove default order and seed `424242` both
   pass.
3. Update `test_timing_baseline.sh` to locate/install-check the pinned Very Good
   CLI and fail with an actionable prerequisite message.
4. Update `report_mobile_ci_run.py` to report test execution, setup share, and
   critical path instead of a one-job shard spread.
5. Document one-command multi-file batching in the contributor test workflow.

### Phase 2: make time and retries controllable

1. Inject a retry delay strategy/config into `VideoEventPublisher`, defaulting
   to the current production behavior.
2. Prove retry attempt counts in tests using an immediate/fake delay and retain
   one focused fake-time policy test for the 2s/4s schedule.
3. Repeat JSON profiling after Phase 1 and prioritize only delays correlated
   with measured execution, starting with the publish-confirmation files.
4. Diagnose the cache-provider concurrency failure with explicit async
   boundaries and fixed stress repetitions before changing concurrency.

### Phase 3: improve signal density

1. Review the 20 slowest files and the name-based weak-test candidates using the
   repository's “can it fail?” rule.
2. Delete only tests that demonstrably cannot catch a distinct regression;
   replace misleading styling/property tests with behavior, accessibility, or
   golden assertions where that contract matters.
3. Reduce 317 skipped cases and 16 optimizer opt-outs through focused root-cause
   fixes. Both existing ratchets must stay monotonic.
4. Add service-integration timing and result artifacts once that workflow has a
   runnable environment; then decide whether it should be scheduled or
   path-triggered.

## Acceptance criteria

The first implementation slices should target:

- common one-to-five-file local feedback at or below a 5-second warm median on
  the measured reference machine;
- full local optimized suite at or below 285 seconds after the confirmed retry
  fix, with all 11,962 passing and 317 skipped cases still represented;
- CI test-execution p50 at or below 400 seconds and p95 at or below 425 seconds
  after the confirmed retry fix;
- overall Mobile CI p50 at or below 8 minutes after Phase 1;
- zero increases in skipped cases, optimizer opt-outs, `Future.delayed` debt,
  untested-service entries, or lowered package coverage floors;
- fixed-seed `424242` and random-order optimized runs both passing;
- controlled mutations for the critical behavior being optimized still
  producing the expected failure;
- no new custom orchestration layer unless later measurements show that batching
  explicit affected paths is insufficient.

Targets should be re-baselined after each merged slice. Improvements must be
reported as medians/ranges with the same command and environment, not a single
best run.

## Risks and rollback

- **Removing waits could stop testing retry behavior.** Keep retry-policy math
  and attempt count in a dedicated fake-time test; remove real waiting only from
  tests whose contract is the final outcome.
- **Selective local tests can miss dependencies.** Selection is a convenience
  lane, never the only merge gate. The full randomized optimized suite remains
  mandatory.
- **Combining CI jobs could increase wall time.** Preserve parallel jobs unless
  a compute-cost experiment includes wall-time evidence.
- **Higher concurrency can expose or create resource races.** Do not raise CI
  above its four-vCPU match until fixed-seed stress runs are clean.
- **Deleting superficial tests can hide real intent.** Require a stated
  plausible regression and mutation or equivalent evidence before deletion;
  replace the test when the intended contract is real.

Every proposed change is independently reversible. If a slice regresses random
ordering, coverage, or failure quality, revert that slice without rolling back
the measurement/reporting improvements.
