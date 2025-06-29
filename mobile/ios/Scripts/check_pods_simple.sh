#!/bin/bash
# ABOUTME: Simple CocoaPods check script that auto-runs pod install when needed
# ABOUTME: Focused version that doesn't require Flutter in PATH

set -e

echo "🔍 Checking CocoaPods dependencies..."

# Navigate to the iOS directory
cd "${PODS_PODFILE_DIR_PATH}"

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