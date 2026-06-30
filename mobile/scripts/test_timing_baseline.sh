#!/usr/bin/env bash
# ABOUTME: Measures representative Flutter test buckets without writing repo files.
# ABOUTME: Emits JSONL timing records to /tmp by default for before/after comparisons.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEFAULT_OUTPUT="/tmp/divine-test-timing-$(date +%Y%m%d-%H%M%S).jsonl"
OUTPUT="${DIVINE_TEST_TIMING_OUTPUT:-$DEFAULT_OUTPUT}"
MODE="quick"
FAILED=0

usage() {
  cat <<'USAGE'
Usage: scripts/test_timing_baseline.sh [--quick|--full] [--output path]

Runs representative test buckets and writes JSONL records with duration,
exit status, and log path. The default output path is /tmp so normal timing
runs do not dirty the repository.

Modes:
  --quick  app unit, router, golden, and VGV opt-out count buckets
  --full   quick buckets plus services, widgets, selected packages, and
           the CI-equivalent VGV optimized command
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --quick)
      MODE="quick"
      shift
      ;;
    --full)
      MODE="full"
      shift
      ;;
    --output)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --output" >&2
        exit 2
      fi
      OUTPUT="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

mkdir -p "$(dirname "$OUTPUT")"
LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/divine-test-timing.XXXXXX")"

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

run_bucket() {
  local name="$1"
  shift
  local log_file="$LOG_DIR/${name}.log"
  local command="$*"
  local start_epoch
  local end_epoch
  local duration
  local status

  echo "==> $name"
  echo "    $command"
  start_epoch="$(date +%s)"
  "$@" >"$log_file" 2>&1
  status=$?
  end_epoch="$(date +%s)"
  duration=$((end_epoch - start_epoch))

  printf '{"bucket":"%s","status":%s,"duration_seconds":%s,"command":"%s","log":"%s"}\n' \
    "$(json_escape "$name")" \
    "$status" \
    "$duration" \
    "$(json_escape "$command")" \
    "$(json_escape "$log_file")" >>"$OUTPUT"

  if [ "$status" -eq 0 ]; then
    echo "    PASS in ${duration}s"
  else
    FAILED=1
    echo "    FAIL in ${duration}s (log: $log_file)"
  fi
}

run_shell_bucket() {
  local name="$1"
  local command="$2"
  run_bucket "$name" bash -lc "$command"
}

cd "$PROJECT_ROOT"
: >"$OUTPUT"

echo "Writing timing records to $OUTPUT"
echo "Command logs are in $LOG_DIR"

run_bucket app-unit flutter test test/unit --no-pub --reporter=compact
run_bucket app-router flutter test test/router --no-pub --reporter=compact
run_bucket app-goldens scripts/golden.sh verify
run_shell_bucket vgv-opt-out-count \
  "grep -rln \"skip_very_good_optimization\" test | wc -l | tr -d '[:space:]'"

if [ "$MODE" = "full" ]; then
  run_bucket app-services flutter test test/services --no-pub --reporter=compact
  run_bucket app-widgets flutter test test/widgets --no-pub --reporter=compact
  run_bucket package-models flutter test packages/models/test --no-pub --reporter=compact
  run_bucket package-db-client flutter test packages/db_client/test --no-pub --reporter=compact
  run_bucket vgv-optimized very_good test --optimization --concurrency=4 \
    --exclude-tags integration --test-randomize-ordering-seed random
fi

echo "Done. Timing JSONL: $OUTPUT"
exit "$FAILED"
