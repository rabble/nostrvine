#!/usr/bin/env bash
# ABOUTME: Reduces mobile/test to one deterministic shard of *_test.dart files.
# ABOUTME: Lets `very_good test --optimization` build a per-shard merged bundle.

# Mobile CI's `Tests` job is the workflow's critical path. `very_good test
# --optimization` collapses every untagged test file into a single
# .test_optimizer.dart suite — one process — so `--concurrency=4` has nothing
# left to schedule once the 18 skip_very_good_optimization files are done, and
# the bulk of the run is single-core on a 4-vCPU runner.
#
# very_good has no "run this subset" flag, so the shard is selected by removing
# the other shards' *_test.dart files from the checkout before very_good scans
# it. Everything that is not a test entry point — helpers, mocks, fixtures,
# builders, flutter_test_config.dart — is left in place, because the tests that
# remain still import it.
#
# Assignment is round-robin over the lexicographically sorted file list: it is
# deterministic, needs no stored baseline that could drift, and (because sorted
# order groups by directory) spreads each directory's cost across all shards.
#
# This DELETES files. It refuses to run outside CI without --force.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TOTAL=""
INDEX=""
DRY_RUN=0
FORCE=0

usage() {
  cat <<'USAGE'
Usage: scripts/ci/select_test_shard.sh --total N --index I [--dry-run] [--force]

Removes every mobile/test/**/*_test.dart file that does not belong to shard I
of N (0-based), leaving non-test sources untouched.

  --total N   Number of shards (>= 1).
  --index I   This shard, 0 <= I < N.
  --dry-run   Print what would be kept and removed; change nothing.
  --force     Allow running outside CI (this deletes files — be sure).
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --total) TOTAL="${2:-}"; shift 2 ;;
    --index) INDEX="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$TOTAL" in
  ''|*[!0-9]*) echo "❌ --total must be a positive integer (got '${TOTAL}')." >&2; exit 2 ;;
esac
case "$INDEX" in
  ''|*[!0-9]*) echo "❌ --index must be a non-negative integer (got '${INDEX}')." >&2; exit 2 ;;
esac
if [ "$TOTAL" -lt 1 ]; then
  echo "❌ --total must be >= 1 (got '${TOTAL}')." >&2
  exit 2
fi
if [ "$INDEX" -ge "$TOTAL" ]; then
  echo "❌ --index must satisfy 0 <= index < total (got '${INDEX}' of '${TOTAL}')." >&2
  exit 2
fi
if [ "$DRY_RUN" -eq 0 ] && [ "$FORCE" -eq 0 ] && [ "${CI:-}" != "true" ]; then
  echo "❌ Refusing to delete test files outside CI. Use --dry-run, or --force if you mean it." >&2
  exit 2
fi

cd "$PROJECT_ROOT"

all_tests_file="$(mktemp)"
trap 'rm -f "$all_tests_file"' EXIT
find test -type f -name '*_test.dart' | LC_ALL=C sort > "$all_tests_file"

total_files=$(wc -l < "$all_tests_file" | tr -d '[:space:]')
if [ "$total_files" -eq 0 ]; then
  echo "❌ Found no *_test.dart files under test/. Refusing to proceed." >&2
  exit 1
fi

kept=0
removed=0
i=0
while IFS= read -r file; do
  if [ $((i % TOTAL)) -eq "$INDEX" ]; then
    kept=$((kept + 1))
  else
    removed=$((removed + 1))
    if [ "$DRY_RUN" -eq 0 ]; then
      rm -f "$file"
    fi
  fi
  i=$((i + 1))
done < "$all_tests_file"

if [ "$kept" -eq 0 ]; then
  echo "❌ Shard ${INDEX}/${TOTAL} selected 0 test files. Refusing to report a vacuous pass." >&2
  exit 1
fi

verb="Kept"
[ "$DRY_RUN" -eq 1 ] && verb="Would keep"
echo "${verb} ${kept} of ${total_files} test files for shard ${INDEX} of ${TOTAL} (${removed} removed)."
