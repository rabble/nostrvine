#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# E2E Performance Profiler
# Captures docker + app logs during a test run, merges into sorted JSON lines.
#
# Usage:
#   local_stack/profile.sh [test_path]
#   local_stack/profile.sh integration_test/auth/session_expiry_test.dart
#   local_stack/profile.sh integration_test/auth/   (whole directory)
#
# Default: integration_test/auth/
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "${SCRIPT_DIR}/../mobile" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
MERGE_SCRIPT="${SCRIPT_DIR}/merge_logs.py"

# --- Ensure DISPLAY is set for emulator (Hyprland/XWayland) ---
if [[ -z "${DISPLAY:-}" ]]; then
    if [[ -S /tmp/.X11-unix/X1 ]]; then
        export DISPLAY=:1
        echo "Note: Set DISPLAY=:1 (XWayland) for emulator camera support." >&2
    elif [[ -S /tmp/.X11-unix/X0 ]]; then
        export DISPLAY=:0
    fi
fi

TEST_PATH="${1:-integration_test/auth/}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_DIR="${MOBILE_DIR}/test_reports"
REPORT_FILE="${REPORT_DIR}/${TIMESTAMP}.jsonl"

TMPDIR="$(mktemp -d)"
DOCKER_LOG="${TMPDIR}/docker.log"
APP_LOG="${TMPDIR}/app.log"
LOGCAT_LOG="${TMPDIR}/logcat.log"

cleanup() {
    if [[ -n "${DOCKER_PID:-}" ]] && kill -0 "$DOCKER_PID" 2>/dev/null; then
        kill "$DOCKER_PID" 2>/dev/null || true
        wait "$DOCKER_PID" 2>/dev/null || true
    fi
    if [[ -n "${LOGCAT_PID:-}" ]] && kill -0 "$LOGCAT_PID" 2>/dev/null; then
        kill "$LOGCAT_PID" 2>/dev/null || true
        wait "$LOGCAT_PID" 2>/dev/null || true
    fi
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

echo "=== E2E Performance Profiler ===" >&2
echo "Test path:  ${TEST_PATH}" >&2
echo "Report:     ${REPORT_FILE}" >&2
echo "" >&2

# --- Verify docker stack is running ---
if ! docker compose -f "$COMPOSE_FILE" ps --status running -q 2>/dev/null | head -1 | grep -q .; then
    echo "ERROR: Docker stack is not running. Start with: mise run local_up" >&2
    exit 1
fi

# --- Start docker log capture (background, from now only) ---
echo "Starting docker log capture..." >&2
docker compose -f "$COMPOSE_FILE" logs -f -t --since "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    keycast funnelcake-relay funnelcake-api blossom blossom-proxy invite \
    > "$DOCKER_LOG" 2>&1 &
DOCKER_PID=$!

# --- Detect connected Android device ---
DEVICE="$(adb devices | sed -n '2p' | cut -f1)"
if [[ -z "$DEVICE" ]]; then
    echo "ERROR: No Android device connected." >&2
    exit 1
fi
echo "Device:     ${DEVICE}" >&2

# --- Start logcat capture (background, flutter/app logs with timestamps) ---
echo "Starting logcat capture..." >&2
adb -s "$DEVICE" logcat -c 2>/dev/null || true
adb -s "$DEVICE" logcat -v UTC -v year flutter:I BandwidthTracker:I IndividualVideoController:I VideoLoadingMetrics:I C2PAManager:D OpenVineProofMode:D '*:S' > "$LOGCAT_LOG" 2>&1 &
LOGCAT_PID=$!

# --- Run E2E test ---
# Disable errexit so we can capture the exit code through the pipe.
echo "Running: patrol test ${TEST_PATH} ..." >&2
cd "$MOBILE_DIR"
set +e
PATH="$HOME/.pub-cache/bin:$PATH" patrol test \
    --target "$TEST_PATH" \
    --dart-define=DEFAULT_ENV=LOCAL \
    --dart-define=INVITE_SERVER_URL=http://10.0.2.2:43004 \
    2>&1 | tee "$APP_LOG"
TEST_EXIT="${PIPESTATUS[0]}"
set -e

# --- Stop docker log and logcat capture ---
kill "$DOCKER_PID" 2>/dev/null || true
wait "$DOCKER_PID" 2>/dev/null || true
unset DOCKER_PID
kill "$LOGCAT_PID" 2>/dev/null || true
wait "$LOGCAT_PID" 2>/dev/null || true
unset LOGCAT_PID

# --- Merge logs ---
echo "" >&2
echo "Merging logs..." >&2
python3 "$MERGE_SCRIPT" "$DOCKER_LOG" "$LOGCAT_LOG" "$APP_LOG" "$REPORT_FILE"

ENTRY_COUNT="$(wc -l < "$REPORT_FILE" 2>/dev/null || echo 0)"

echo "" >&2
if [[ $TEST_EXIT -eq 0 ]]; then
    echo "Tests PASSED." >&2
else
    echo "Tests FAILED (exit ${TEST_EXIT})." >&2
fi
echo "" >&2
echo "Report: ${REPORT_FILE} (${ENTRY_COUNT} entries)" >&2
echo "Analyze: cat ${REPORT_FILE} | claude 'summarize this E2E test run: errors, slow requests, timeline issues'" >&2

exit "$TEST_EXIT"
