#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Android Emulator Launcher
#
# Handles display/AVD path/Wayland-vs-XWayland detection so the SKILL.md
# documentation can stay short.
#
# Usage:
#   local_stack/emulator.sh                 # Normal launch (windowed)
#   local_stack/emulator.sh --headless      # Offscreen + -no-window
#   local_stack/emulator.sh --wipe          # -wipe-data (storage reset)
#
# Env overrides:
#   AVD_NAME            (default: first emulator -list-avds entry)
#   ANDROID_AVD_HOME    (default: $HOME/.android/avd)
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=android_sdk.sh
source "$SCRIPT_DIR/android_sdk.sh"

MODE="normal"
case "${1:-}" in
    --headless) MODE="headless" ;;
    --wipe)     MODE="wipe" ;;
    "")         ;;
    *)
        echo "Unknown argument: $1" >&2
        echo "Usage: $0 [--headless|--wipe]" >&2
        exit 2
        ;;
esac

if ! command -v emulator >/dev/null 2>&1; then
    echo "ERROR: 'emulator' not on PATH and Android SDK not found." >&2
    echo "Set ANDROID_HOME or install the SDK at \$HOME/Android/Sdk (Linux) / \$HOME/Library/Android/sdk (macOS)." >&2
    exit 1
fi

AVD_NAME="${AVD_NAME:-$(first_available_avd_name)}"
export ANDROID_AVD_HOME="${ANDROID_AVD_HOME:-$HOME/.android/avd}"

if [[ -z "$AVD_NAME" ]]; then
    echo "ERROR: No Android AVD found. Create one in Android Studio or pass AVD_NAME=<name>." >&2
    exit 1
fi

EMULATOR_ARGS=(-avd "$AVD_NAME" -gpu host -no-snapshot-load)

configure_windowed_display() {
    local missing_display_message="$1"
    local display_to_use

    if [[ "$(uname -s)" == "Darwin" ]]; then
        return
    fi

    display_to_use="$(detect_x11_display)"
    if [[ -z "$display_to_use" ]]; then
        echo "ERROR: No X11 socket found at /tmp/.X11-unix/X*." >&2
        echo "$missing_display_message" >&2
        exit 1
    fi
    export DISPLAY="$display_to_use"
    export QT_QPA_PLATFORM=xcb
}

case "$MODE" in
    headless)
        export QT_QPA_PLATFORM=offscreen
        EMULATOR_ARGS+=(-no-window)
        echo "Launching headless: $AVD_NAME" >&2
        ;;
    wipe)
        # -wipe-data needs a window so caller can confirm the boot — same path as normal.
        configure_windowed_display "On Hyprland/Wayland, ensure XWayland is running."
        EMULATOR_ARGS+=(-wipe-data)
        echo "Launching with -wipe-data: $AVD_NAME" >&2
        ;;
    normal)
        configure_windowed_display "On Hyprland/Wayland, ensure XWayland is running, or use --headless."
        echo "Launching: $AVD_NAME" >&2
        ;;
esac

exec emulator "${EMULATOR_ARGS[@]}"
