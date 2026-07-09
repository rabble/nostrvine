#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Manual Android local-stack runner
#
# Usage:
#   local_stack/run_android_local.sh [device_id] [debug|profile|release]
#
# Defaults to the first connected Android emulator and debug mode.
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "${SCRIPT_DIR}/../mobile" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
ANDROID_PACKAGE_ID="co.openvine.app"

# shellcheck source=android_sdk.sh
source "${SCRIPT_DIR}/android_sdk.sh"

DEVICE_ARG="${1:-}"
BUILD_MODE="${2:-debug}"

case "$BUILD_MODE" in
    debug|profile|release) ;;
    *)
        echo "ERROR: Unknown build mode: ${BUILD_MODE}" >&2
        echo "Usage: $0 [device_id] [debug|profile|release]" >&2
        exit 2
        ;;
esac

if ! docker compose -f "$COMPOSE_FILE" ps --status running -q 2>/dev/null | head -1 | grep -q .; then
    echo "ERROR: Docker stack is not running. Start with: mise run local_up" >&2
    exit 1
fi

if ! command -v adb >/dev/null 2>&1; then
    echo "ERROR: 'adb' not on PATH and Android SDK not found." >&2
    echo "Set ANDROID_HOME or install the SDK at \$HOME/Android/Sdk (Linux) / \$HOME/Library/Android/sdk (macOS)." >&2
    exit 1
fi

if [[ -n "$DEVICE_ARG" ]]; then
    if [[ "$DEVICE_ARG" != emulator-* ]]; then
        echo "ERROR: ${DEVICE_ARG} is not an Android emulator." >&2
        echo "This local-stack command uses Android emulator host URLs. Start one with: mise run emulator" >&2
        exit 1
    fi

    DEVICE="$DEVICE_ARG"
else
    DEVICE="$(adb devices | awk 'NR > 1 && $1 ~ /^emulator-/ && $2 == "device" { print $1; exit }')"
fi

if [[ -z "$DEVICE" ]]; then
    echo "ERROR: No Android emulator connected. Start one with: mise run emulator" >&2
    exit 1
fi

echo "Running Divine against the local stack on Android emulator: ${DEVICE}" >&2
echo "Invite server: http://10.0.2.2:43004" >&2
echo "Clearing persisted app data for ${ANDROID_PACKAGE_ID} so LOCAL is deterministic" >&2
adb -s "$DEVICE" shell pm clear "$ANDROID_PACKAGE_ID" >/dev/null

cd "$MOBILE_DIR"
exec flutter run \
    -d "$DEVICE" \
    --"$BUILD_MODE" \
    --dart-define=DEFAULT_ENV=LOCAL \
    --dart-define=INVITE_SERVER_URL=http://10.0.2.2:43004
