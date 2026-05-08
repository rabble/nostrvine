#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

usage() {
    cat <<'USAGE'
Usage: ./clear_cache.sh [--full]

Default behavior (fast cleanup):
  - Clear iOS Simulator cache directories
  - Clear Android emulator app data
  - Clear macOS container data
  - Clear test Hive files

Use --full for project-wide reset:
  - Includes fast cleanup
  - Runs flutter clean
  - Removes iOS/macOS Pod state
  - Removes Xcode DerivedData

Use this instead of blind, frequent `flutter clean`.
USAGE
}

FULL_RESET=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --full)
            FULL_RESET=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $1"
            usage
            exit 1
            ;;
    esac
    shift
done

echo "🧹 Clearing OpenVine cache and database files..."

# Fast cleanup is always safe for day-to-day iteration.
echo "⚡ Running fast cache reset (default)"

# Clear iOS Simulator data
if [ -d "$HOME/Library/Developer/CoreSimulator" ]; then
    echo "📱 Clearing iOS Simulator data..."
    rm -rf "$HOME/Library/Developer/CoreSimulator/Devices"/*/data/Containers/Data/Application/*/Library/Caches/openvine
    rm -rf "$HOME/Library/Developer/CoreSimulator/Devices"/*/data/Containers/Data/Application/*/Documents/openvine
fi

# Clear Android Emulator data
if [ -d "$HOME/.android/avd" ]; then
    echo "🤖 Clearing Android Emulator data..."
    find "$HOME/.android/avd" -name "*openvine*" -type d -exec rm -rf {} + 2>/dev/null || true
fi

# Clear macOS app data
if [ -d "$HOME/Library/Containers/co.openvine.mobile" ]; then
    echo "💻 Clearing macOS app data..."
    rm -rf "$HOME/Library/Containers/co.openvine.mobile/Data/Library/Caches"
    rm -rf "$HOME/Library/Containers/co.openvine.mobile/Data/Documents"
fi

# Clear test Hive files
rm -f test_hive/*.hive
rm -f test_hive/*.lock

echo "✅ Fast cache cleanup done."

if [[ "$FULL_RESET" == "true" ]]; then
    echo "🔥 Running full reset"

    if [[ -f "pubspec.yaml" ]]; then
        echo "🧼 Running flutter clean..."
        flutter clean
    else
        echo "⚠️  Skipping flutter clean: no Flutter project root here"
    fi

    echo "🧹 Removing iOS/macOS Pod state..."
    rm -rf ios/Pods ios/Podfile.lock
    rm -rf macos/Pods macos/Podfile.lock

    if [ -d "$HOME/Library/Developer/Xcode/DerivedData" ]; then
        echo "🧹 Removing Xcode DerivedData..."
        rm -rf "$HOME/Library/Developer/Xcode/DerivedData"
    fi

    echo "✅ Full reset done."
fi

echo "⚠️  Note: You'll need to log in again and some local settings may be reset."
