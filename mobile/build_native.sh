#!/bin/bash
set -euo pipefail

# DEPRECATED: build_ios.sh and build_macos.sh are now the primary scripts.

usage() {
    cat <<'USAGE'
Usage: ./build_native.sh [ios|macos|both] [debug|release] [options]

This script is maintained for backward compatibility only.
Use platform-specific scripts directly for faster local iterations:
  ./build_ios.sh [debug|release] [--codegen] [--pod-reset]
  ./build_macos.sh [debug|release] [--codegen] [--pod-reset]

Options accepted by delegated scripts are forwarded:
  --increment
  --codegen
  --no-codegen
  --pod-reset
  --no-pub-get
  --no-pod-install
USAGE
}

PLATFORM=""
BUILD_MODE="debug"
FORWARDED=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        ios|macos|both)
            PLATFORM="$1"
            ;;
        debug|release)
            BUILD_MODE="$1"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            FORWARDED+=("$1")
            ;;
    esac
    shift
done

if [[ -z "$PLATFORM" ]]; then
    echo "📱 Which platform would you like to build?"
    echo "1) iOS"
    echo "2) macOS"
    echo "3) both"
    read -p "Enter choice (1-3): " choice

    case "$choice" in
        1) PLATFORM="ios" ;;
        2) PLATFORM="macos" ;;
        3) PLATFORM="both" ;;
        *)
            echo "❌ Invalid choice"
            exit 1
            ;;
    esac
fi

if [[ "$PLATFORM" == "ios" ]]; then
    echo "⚠️  build_native.sh is deprecated; running build_ios.sh"
    exec ./build_ios.sh "$BUILD_MODE" "${FORWARDED[@]}"
elif [[ "$PLATFORM" == "macos" ]]; then
    echo "⚠️  build_native.sh is deprecated; running build_macos.sh"
    exec ./build_macos.sh "$BUILD_MODE" "${FORWARDED[@]}"
else
    echo "⚠️  build_native.sh is deprecated; running build_ios.sh then build_macos.sh"
    ./build_ios.sh "$BUILD_MODE" "${FORWARDED[@]}"
    echo ""
    ./build_macos.sh "$BUILD_MODE" "${FORWARDED[@]}"
fi
