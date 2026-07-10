# Test Performance Investigation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Measure divine-mobile's local and CI test feedback loops, identify evidence-backed performance and coverage-quality bottlenecks, and publish a prioritized improvement plan without weakening regression protection.

**Architecture:** Treat the investigation as a reproducible benchmark pipeline rather than an optimization patch. Capture environment, inventory, local timing, per-file timing, CI history, static test-cost indicators, and behavioral-coverage samples into temporary artifacts, then synthesize them into one committed report; exploratory mutations and timing artifacts stay outside the repository.

**Tech Stack:** Flutter 3.44, Dart test JSON reporter, Very Good CLI optimizer, Bash, Python 3, GitHub Actions API via `gh`, LCOV, Markdown.

---

### Task 1: Establish a clean, reproducible baseline

**Files:**
- Create: `docs/superpowers/plans/2026-07-10-test-performance-investigation.md`
- Create later: `mobile/docs/TEST_PERFORMANCE_INVESTIGATION_2026-07-10.md`
- Read: `AGENTS.md`
- Read: `.claude/rules/testing.md`
- Read: `mobile/docs/TEST_PERFORMANCE.md`
- Read: `.github/workflows/mobile_ci.yaml`

- [x] **Step 1: Record the immutable source revision and environment**

Run from the worktree root:

```bash
git rev-parse HEAD
git status --short
uname -a
sw_vers
sysctl -n machdep.cpu.brand_string
sysctl -n hw.logicalcpu
sysctl -n hw.memsize
flutter --version
dart --version
gh --version
```

Expected: the branch starts at fresh `origin/main`, only this plan is modified, and all tool versions are captured in `/tmp/divine-test-investigation/environment.txt`.

- [x] **Step 2: Inventory test files and policy-sensitive constructs**

Run exact file counts for `mobile/test`, `mobile/packages/*/test`, and `mobile/integration_test`. Count `skip_very_good_optimization`, `Future.delayed`, `pumpAndSettle`, file-level tags, skipped tests, and coverage floors with `find` and `rg`. Save machine-readable tables under `/tmp/divine-test-investigation/`.

Expected: counts reconcile with the checked-in baselines and each result identifies its source command.

- [x] **Step 3: Verify a clean representative test bucket**

Run from `mobile/`:

```bash
flutter test test/unit --no-pub --reporter=compact
```

Expected: exit 0. If it fails, preserve the complete log and investigate the failure before proceeding.

### Task 2: Measure local feedback-loop cost

**Files:**
- Read: `mobile/scripts/test_timing_baseline.sh`
- Temporary outputs: `/tmp/divine-test-investigation/local/*.jsonl`
- Temporary logs: `/tmp/divine-test-investigation/local/logs/`

- [x] **Step 1: Capture first-run and warm representative timings**

Measure representative BLoC, repository, service, widget, router, and golden files. Run each selected non-golden file once for first-run timing and three additional times for warm median/min/max. Record wall time and exit status separately from `flutter pub get`.

- [x] **Step 2: Run the supported quick baseline**

```bash
scripts/test_timing_baseline.sh --quick --output /tmp/divine-test-investigation/local/quick.jsonl
```

Expected: every bucket reports status 0, or any failure is preserved and root-caused.

- [x] **Step 3: Run the supported full baseline**

```bash
scripts/test_timing_baseline.sh --full --output /tmp/divine-test-investigation/local/full.jsonl
```

Expected: app, package, golden, and CI-equivalent buckets produce comparable wall-clock records.

- [x] **Step 4: Profile per-file execution**

Run the app suite with the JSON reporter and exact CI semantics. Parse suite start/done and test events into per-file elapsed-time estimates while distinguishing optimizer-merged files from separately launched opt-outs.

```bash
very_good test --optimization --concurrency=4 --exclude-tags integration \
  --test-randomize-ordering-seed random --reporter=json
```

Expected: a ranked slow-file table plus explicit limitations of the reporter/optimizer combination. If the CLI does not forward `--reporter=json`, use direct `flutter test --reporter=json` on measured directories and document the semantic difference.

### Task 3: Measure CI critical path and historical variability

**Files:**
- Read: `.github/workflows/mobile_ci.yaml`
- Read: `.github/workflows/mobile_service_integration_tests.yaml`
- Read: `mobile/scripts/ci/report_mobile_ci_run.py`
- Temporary outputs: `/tmp/divine-test-investigation/ci/`

- [x] **Step 1: Fetch recent successful Mobile CI runs**

Use `gh api` to retrieve at least 20 recent completed `pull_request` runs of Mobile CI, then fetch their jobs and steps. Exclude cancelled runs from duration percentiles but report their count.

- [x] **Step 2: Calculate p50/p95 wall time and setup overhead**

For workflow wall time, Tests job time, dependency/setup steps, generated-files job, format, analyze, and final aggregation, calculate sample count, median, p95, min, and max. Identify duplicated setup time and the actual critical path.

- [x] **Step 3: Validate existing reporting tools against current workflow shape**

Run `mobile/scripts/ci/report_mobile_ci_run.py` on a recent run and compare its output with raw Actions data. Document obsolete assumptions such as test-shard naming if present.

### Task 4: Audit coverage usefulness and test-cost causes

**Files:**
- Read: representative tests under `mobile/test/{blocs,services,widgets,screens,router}`
- Read: representative tests under `mobile/packages/*/test`
- Temporary outputs: `/tmp/divine-test-investigation/audit/`

- [x] **Step 1: Rank static cost indicators**

Rank files by `Future.delayed`, `pumpAndSettle`, pump count, test count, lines, mock declarations, app-shell construction, database setup, and optimizer opt-out. Correlate these indicators with measured runtimes rather than treating them as proof by themselves.

- [x] **Step 2: Build a product-risk coverage map**

Map authentication/key management, Nostr events, feed/caching, recording/editing/publishing, drafts, DMs/privacy/moderation/minor safety, routing/account state, persistence/serialization, and repository/client recovery to concrete test files. Record strong protection, gaps, redundancy, and expensive layer choices with file evidence.

- [x] **Step 3: Sample test usefulness**

Inspect all measured top-cost files plus a stratified sample from BLoC, repository, service, widget, router, golden, package, and integration layers. Classify assertions as behavioral protection, implementation-detail coupling, tautology, redundant protection, or unclear. Never generalize sample percentages to the full suite without labeling the inference.

- [x] **Step 4: Perform controlled mutation checks**

Select at least three critical behaviors from different layers. Make one minimal local mutation at a time, run the claimed protecting test, record whether it fails for the expected reason, and restore only the investigation's own mutation before continuing.

Expected: red evidence for each useful test and a clean worktree after every mutation.

### Task 5: Test minimal optimization hypotheses

**Files:**
- Temporary experiment patches only; restore before report commit.

- [x] **Step 1: State single-variable hypotheses**

Choose the highest-evidence candidates from profiling. Include at least one local targeted-lane experiment, one test-implementation experiment (for example replacing a real wait or broad settle), and one runner/CI configuration experiment that can be measured without weakening gates.

- [x] **Step 2: Measure before and after**

For each experiment, run identical commands at least three warm times before and after. Record medians, range, pass/fail status, random-order/isolation implications, and maintenance cost.

- [x] **Step 3: Restore exploratory changes**

Use a reviewed diff to remove only experiment changes. Preserve the plan and report. Confirm with:

```bash
git status --short
git diff -- mobile/lib mobile/test mobile/packages .github/workflows mobile/scripts
```

Expected: no implementation or workflow experiment remains.

### Task 6: Publish the investigation report

**Files:**
- Create: `mobile/docs/TEST_PERFORMANCE_INVESTIGATION_2026-07-10.md`
- Modify: `docs/superpowers/plans/2026-07-10-test-performance-investigation.md` (check completed steps)

- [x] **Step 1: Write the evidence-backed report**

Include executive summary, inventory, environment, reproducible local baseline, CI history, ranked hotspots, root causes, coverage-risk map, usefulness sample, mutation evidence, experiment results, approach comparison, recommended target lanes, phased implementation slices, quantified acceptance criteria, risks, rollback strategy, and exact developer commands.

- [x] **Step 2: Self-review the report**

Check every numerical claim against `/tmp` evidence; label inference separately from measurement; remove secrets, internal credentials, placeholders, unsupported causality, and recommendations that lower coverage or isolation gates.

- [x] **Step 3: Verify documentation and repository cleanliness**

```bash
git diff --check
git status --short
rg -n "TO""DO|TB""D|PLACE""HOLDER" \
  docs/superpowers/plans/2026-07-10-test-performance-investigation.md \
  mobile/docs/TEST_PERFORMANCE_INVESTIGATION_2026-07-10.md
```

Expected: no whitespace errors, no placeholders, and only the plan/report are changed.

- [x] **Step 4: Commit the report**

```bash
git add docs/superpowers/plans/2026-07-10-test-performance-investigation.md \
  mobile/docs/TEST_PERFORMANCE_INVESTIGATION_2026-07-10.md
git commit -m "docs(test): investigate mobile test feedback performance"
```

- [x] **Step 5: Rebase, verify, push, and open the PR**

```bash
git fetch origin
git rebase origin/main
git diff --check origin/main...HEAD
git status --short
git push -u origin research/test-performance-investigation
gh pr create --base main \
  --title "docs(test): investigate mobile test feedback performance" \
  --body-file /tmp/divine-test-investigation/pr-body.md
```

Expected: a clean branch, Conventional Commit PR title, main as base, and report-only diff.
