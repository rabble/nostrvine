# Mobile CI Parallelization Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce GitHub Actions PR wall-clock time for `Mobile CI` by splitting static checks into parallel jobs and sharding Flutter tests across multiple runners while preserving full PR coverage.

**Architecture:** Keep the existing `Mobile CI` workflow name and trigger behavior, but replace the single serial `build` job with parallel jobs for generated files, formatting, analysis, and a matrix-based test job. Put test sharding logic in a small repo script so the workflow stays readable and shard behavior is deterministic and easy to tune from 4 shards to a higher count later.

**Tech Stack:** GitHub Actions, Ubuntu runners, Flutter 3.41.4, Dart, Bash

---

## File Structure

**Modify**
- `.github/workflows/mobile_ci.yaml`

**Create**
- `mobile/scripts/ci/run_flutter_test_shard.sh`

**Why this structure**
- Keep workflow orchestration in `.github/workflows/mobile_ci.yaml`.
- Move shard selection logic into a script so shard behavior can be tested locally and changed without turning the workflow file into shell soup.
- Avoid broader CI refactors for now. The smallest reviewable change is one workflow file plus one helper script.

## Chunk 1: Add Deterministic Test Sharding Helper

### Task 1: Create the shard runner script

**Files:**
- Create: `mobile/scripts/ci/run_flutter_test_shard.sh`
- Verify: `mobile/scripts/ci/run_flutter_test_shard.sh`

- [ ] **Step 1: Create the script file with strict shell settings**

Create `mobile/scripts/ci/run_flutter_test_shard.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <shard-index> <shard-count>" >&2
  exit 64
fi

shard_index="$1"
shard_count="$2"

if ! [[ "$shard_index" =~ ^[0-9]+$ ]] || ! [[ "$shard_count" =~ ^[0-9]+$ ]]; then
  echo "shard index and shard count must be integers" >&2
  exit 64
fi

if (( shard_count < 1 )); then
  echo "shard count must be >= 1" >&2
  exit 64
fi

if (( shard_index < 0 || shard_index >= shard_count )); then
  echo "shard index must be between 0 and shard_count - 1" >&2
  exit 64
fi

mapfile -t test_files < <(
  find test -type f -name '*_test.dart' \
    ! -path 'test/integration/*' \
    | LC_ALL=C sort
)

selected_files=()
for i in "${!test_files[@]}"; do
  if (( i % shard_count == shard_index )); then
    selected_files+=("${test_files[$i]}")
  fi
done

echo "Shard ${shard_index}/${shard_count}"
echo "Selected ${#selected_files[@]} test files"

if (( ${#selected_files[@]} == 0 )); then
  echo "No test files selected for this shard"
  exit 0
fi

printf '%s\n' "${selected_files[@]}"

flutter test --exclude-tags integration "${selected_files[@]}"
```

- [ ] **Step 2: Make the script executable**

Run:

```bash
chmod +x mobile/scripts/ci/run_flutter_test_shard.sh
```

Expected: command exits successfully with no output.

- [ ] **Step 3: Verify shard selection works for shard 0**

Run:

```bash
cd mobile
scripts/ci/run_flutter_test_shard.sh 0 4
```

Expected:
- The script prints `Shard 0/4`
- It lists a non-zero number of `*_test.dart` files
- It starts running only that shard’s tests

Stop the run after confirming file selection if the full test execution is too slow during this spot check.

- [ ] **Step 4: Verify shard selection works for the last shard**

Run:

```bash
cd mobile
scripts/ci/run_flutter_test_shard.sh 3 4
```

Expected:
- The script prints `Shard 3/4`
- It lists a different subset of test files
- It exits successfully or starts running only that shard’s tests

- [ ] **Step 5: Commit the helper script**

```bash
git add mobile/scripts/ci/run_flutter_test_shard.sh
git commit -m "ci: add Flutter test shard runner"
```

## Chunk 2: Split Mobile CI into Parallel Jobs

### Task 2: Replace the serial workflow with parallel jobs

**Files:**
- Modify: `.github/workflows/mobile_ci.yaml`
- Use: `mobile/scripts/ci/run_flutter_test_shard.sh`

- [ ] **Step 1: Keep workflow triggers and top-level concurrency unchanged**

Preserve:

```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

Expected: PR coverage remains identical to today.

- [ ] **Step 2: Replace the single `build` job with four parallel job groups**

Restructure `.github/workflows/mobile_ci.yaml` into:
- `generated-files`
- `format`
- `analyze`
- `tests` (matrix)

Each job should:
- use `runs-on: ubuntu-latest`
- set `defaults.run.working-directory: mobile/`
- run `actions/checkout@v4`
- run `subosito/flutter-action@v2` with:

```yaml
with:
  flutter-version: "3.41.4"
  channel: "stable"
  cache: true
```

- run `flutter pub get`

Expected: jobs can run independently without cross-job artifacts.

- [ ] **Step 3: Move generated file verification into its own job**

Use the existing command unchanged inside `generated-files`:

```yaml
- name: Verify generated files are up-to-date
  run: |
    dart run build_runner build --delete-conflicting-outputs
    if [ -n "$(git status --porcelain)" ]; then
      echo "⚠️ Generated files are out of date. Please run 'dart run build_runner build' and commit the changes."
      git diff --name-only
      exit 1
    fi
```

Expected: generator-backed regressions still fail PRs, but no longer block format/analyze/test from starting.

- [ ] **Step 4: Move formatting into its own job**

Add a `format` job using:

```yaml
- name: Check formatting
  run: dart format --output=none --set-exit-if-changed lib test integration_test
```

Expected: formatting failures come back independently from test/analyze failures.

- [ ] **Step 5: Move analysis into its own job**

Add an `analyze` job using:

```yaml
- name: Analyze code
  run: flutter analyze lib test integration_test
```

Expected: analyzer failures are reported separately and sooner.

- [ ] **Step 6: Add a 4-shard test matrix**

Create a `tests` job with:

```yaml
strategy:
  fail-fast: false
  matrix:
    shard_index: [0, 1, 2, 3]
    shard_count: [4]
```

Use names like:

```yaml
name: Tests (shard ${{ matrix.shard_index + 1 }}/${{ matrix.shard_count }})
```

Run:

```yaml
- name: Run Flutter test shard
  run: scripts/ci/run_flutter_test_shard.sh ${{ matrix.shard_index }} ${{ matrix.shard_count }}
```

Expected:
- test workload is split across 4 runners
- one failing shard does not cancel the other 3
- overall PR wall-clock time is driven by the slowest shard rather than the full serial test suite

- [ ] **Step 7: Keep integration-tag behavior unchanged**

Do not add integration tests to this workflow. Preserve the current exclusion behavior via:

```bash
flutter test --exclude-tags integration
```

Expected: no surprise expansion in scope or runtime.

- [ ] **Step 8: Validate the workflow YAML**

Run:

```bash
python3 - <<'PY'
import yaml
from pathlib import Path

path = Path(".github/workflows/mobile_ci.yaml")
with path.open() as fh:
    yaml.safe_load(fh)
print("yaml ok")
PY
```

Expected: `yaml ok`

- [ ] **Step 9: Review the final workflow shape**

Run:

```bash
sed -n '1,260p' .github/workflows/mobile_ci.yaml
```

Expected:
- one workflow
- four top-level jobs
- test matrix with four shards
- no accidental trigger or permission changes

- [ ] **Step 10: Commit the workflow split**

```bash
git add .github/workflows/mobile_ci.yaml
git commit -m "ci: parallelize mobile CI checks"
```

## Chunk 3: Verification and Rollout

### Task 3: Verify locally and in GitHub Actions

**Files:**
- Verify: `.github/workflows/mobile_ci.yaml`
- Verify: `mobile/scripts/ci/run_flutter_test_shard.sh`

- [ ] **Step 1: Run shard script smoke checks locally**

Run:

```bash
cd mobile
scripts/ci/run_flutter_test_shard.sh 0 4
scripts/ci/run_flutter_test_shard.sh 1 4
```

Expected:
- both commands select files
- neither crashes from argument parsing or empty selections

- [ ] **Step 2: Run the non-test local checks once before opening the PR**

Run:

```bash
cd mobile
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze lib test integration_test
```

Expected: commands pass, or any failures are fixed before PR.

- [ ] **Step 3: Open the PR and inspect Actions timing**

After pushing, verify in GitHub Actions that:
- `generated-files`, `format`, `analyze`, and all 4 `tests` shards start in parallel
- no shard is starved waiting on another job
- total PR wall-clock time is meaningfully lower than the previous ~20 minutes

Expected:
- wall-clock time should trend closer to the longest single lane rather than the sum of all lanes

- [ ] **Step 4: Capture follow-up tuning data**

Record:
- total workflow wall-clock time
- longest test shard duration
- shortest test shard duration
- generated-files duration

Expected: enough data to decide whether to stay at 4 shards or increase to 6 or 8 later.

- [ ] **Step 5: If shard imbalance is severe, schedule a follow-up**

If one shard is much slower than the others, create a follow-up task to:
- increase shard count from 4 to 6 or 8, or
- change shard assignment logic from simple modulo to duration-aware buckets

Do not expand scope in this PR unless imbalance is catastrophic.

- [ ] **Step 6: Final commit and push hygiene**

Run:

```bash
git status --short
```

Expected: only the intended workflow/script changes are present before final push.

## Notes for Execution

- Optimize for developer wall-clock time, not minimum CI minutes.
- Avoid adding new workflow triggers, path filters, or conditional skips in this change.
- Keep the initial shard count at 4. It is the lowest-complexity parallel step that should produce a noticeable drop in PR wait time.
- Do not bundle unrelated CI refactors into this work.

