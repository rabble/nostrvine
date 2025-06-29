#!/bin/bash
# ABOUTME: Enhanced CocoaPods check script that auto-runs pod install when needed
# ABOUTME: Replaces the default CocoaPods check to prevent build failures

set -e

echo "🔍 Checking CocoaPods dependencies..."

# Navigate to the macOS directory (script is in macos/Scripts/)
cd "${PODS_PODFILE_DIR_PATH}"

# Setup PATH to include Flutter
export PATH="$PATH:$HOME/flutter/bin"
export PATH="$PATH:$HOME/.flutter/bin"
export PATH="$PATH:/usr/local/flutter/bin"
export PATH="$PATH:/opt/flutter/bin"
export PATH="$PATH:/opt/homebrew/bin"
export PATH="$PATH:/Applications/flutter/bin"

# Also check if FLUTTER_ROOT is set
if [ -n "$FLUTTER_ROOT" ]; then
    export PATH="$PATH:$FLUTTER_ROOT/bin"
fi

# First ensure Flutter dependencies are up to date (if flutter is available)
if command -v flutter &> /dev/null; then
    echo "📦 Ensuring Flutter dependencies are current..."
    cd ..
    flutter pub get
    cd macos
else
    echo "⚠️  Flutter not found in PATH, skipping flutter pub get"
fi

# Check if pod install is needed
if [ ! -f "${PODS_ROOT}/Manifest.lock" ]; then
    echo "⚠️  Manifest.lock not found. Running pod install..."
    pod install
elif ! diff "${PODS_PODFILE_DIR_PATH}/Podfile.lock" "${PODS_ROOT}/Manifest.lock" > /dev/null; then
    echo "⚠️  The sandbox is not in sync with the Podfile.lock. Running pod install..."
    pod install
else
    echo "✅ CocoaPods dependencies are up to date"
fi

# This output is used by Xcode 'outputs' to avoid re-running this script phase
echo "SUCCESS" > "${SCRIPT_OUTPUT_FILE_0}"