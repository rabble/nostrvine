#!/usr/bin/env bash
# ABOUTME: Retries the sqlite3mc native-asset hook before Mobile CI tests.
# ABOUTME: A single dropped GitHub Releases GET must not fail the shard (#7197).

# package:sqlite3 downloads libsqlite3mc.*.so from GitHub Releases in one
# unretried GET. Linux test shards do that on a fresh VM. A truncated
# connection fails the hook and GitHub's merge queue ejects the PR.
#
# This script runs the hook through `dart run tools/warmup_sqlite3mc.dart`
# and retries. Pair it with actions/cache on
# .dart_tool/hooks_runner/shared so later jobs skip hook downloads.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

ATTEMPTS="${SQLITE3MC_WARMUP_ATTEMPTS:-5}"
SLEEP_SECS="${SQLITE3MC_WARMUP_SLEEP_SECS:-2}"
WARMUP_CMD="${SQLITE3MC_WARMUP_CMD:-dart run tools/warmup_sqlite3mc.dart}"

if ! [[ "$ATTEMPTS" =~ ^[1-9][0-9]*$ ]]; then
  echo "SQLITE3MC_WARMUP_ATTEMPTS must be a positive integer, got: ${ATTEMPTS}" >&2
  exit 2
fi

if ! [[ "$SLEEP_SECS" =~ ^[0-9]+$ ]]; then
  echo "SQLITE3MC_WARMUP_SLEEP_SECS must be a non-negative integer, got: ${SLEEP_SECS}" >&2
  exit 2
fi

attempt=1
while (( attempt <= ATTEMPTS )); do
  echo "sqlite3mc warmup attempt ${attempt}/${ATTEMPTS}"
  if bash -c "$WARMUP_CMD"; then
    echo "sqlite3mc warmup succeeded on attempt ${attempt}"
    exit 0
  fi
  if (( attempt == ATTEMPTS )); then
    echo "sqlite3mc warmup failed after ${ATTEMPTS} attempts" >&2
    exit 1
  fi
  sleep "$SLEEP_SECS"
  attempt=$((attempt + 1))
done
