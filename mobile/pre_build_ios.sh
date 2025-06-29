#!/bin/bash
# ABOUTME: Pre-build script for iOS Xcode builds to ensure CocoaPods sync
# ABOUTME: Can be added as a pre-action in Xcode scheme to fix pod install issues

set -e

echo "🔧 Pre-build: Ensuring iOS CocoaPods dependencies are synced..."

# Get the directory where this script is located (should be project root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Find Flutter command
FLUTTER_CMD=""
if command -v flutter >/dev/null 2>&1; then
    FLUTTER_CMD="flutter"
elif [ -n "$FLUTTER_ROOT" ] && [ -f "$FLUTTER_ROOT/bin/flutter" ]; then
    FLUTTER_CMD="$FLUTTER_ROOT/bin/flutter"
elif [ -f "/opt/homebrew/Caskroom/flutter/3.27.4/flutter/bin/flutter" ]; then
    FLUTTER_CMD="/opt/homebrew/Caskroom/flutter/3.27.4/flutter/bin/flutter"
else
    echo "⚠️  Flutter not found, skipping pub get..."
    FLUTTER_CMD=""
fi

# Ensure Flutter pub get is run first (if Flutter is available)
if [ -n "$FLUTTER_CMD" ]; then
    echo "📦 Running flutter pub get..."
    "$FLUTTER_CMD" pub get
else
    echo "⚠️  Skipping flutter pub get (Flutter not found)"
fi

# Navigate to iOS directory
cd ios

# Set environment for CocoaPods to avoid Ruby issues
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Ensure we use the correct Ruby environment (rbenv if available)
if [ -d "$HOME/.rbenv" ]; then
    export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init -)"
fi

# Check if CocoaPods needs to be installed or updated
if [ ! -f "Pods/Manifest.lock" ] || [ ! -d "Pods" ]; then
    echo "⚠️  CocoaPods not found, running pod install..."
    pod install --verbose
elif [ "Podfile.lock" -nt "Pods/Manifest.lock" ]; then
    echo "⚠️  Podfile.lock is newer than Manifest.lock, running pod install..."
    pod install --verbose
else
    echo "✅ CocoaPods dependencies are up to date"
fi

echo "✅ Pre-build iOS setup complete!"