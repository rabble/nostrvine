#!/bin/bash
# ABOUTME: Pre-build script for macOS Xcode builds to ensure CocoaPods sync
# ABOUTME: Can be added as a pre-action in Xcode scheme to fix pod install issues

set -e

echo "🔧 Pre-build: Ensuring macOS CocoaPods dependencies are synced..."

# Get the directory where this script is located (should be project root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Ensure Flutter pub get is run first
echo "📦 Running flutter pub get..."
flutter pub get

# Navigate to macOS directory
cd macos

# Check if CocoaPods needs to be installed or updated
if [ ! -f "Pods/Manifest.lock" ] || [ ! -d "Pods" ]; then
    echo "⚠️  CocoaPods not found, running pod install..."
    pod install
elif [ "Podfile.lock" -nt "Pods/Manifest.lock" ]; then
    echo "⚠️  Podfile.lock is newer than Manifest.lock, running pod install..."
    pod install
else
    echo "✅ CocoaPods dependencies are up to date"
fi

echo "✅ Pre-build macOS setup complete!"