#!/bin/bash
# ABOUTME: Pre-action of the shared Runner scheme: syncs CocoaPods before every Xcode iOS build.
# ABOUTME: Runs no Flutter command; plugin injection would reset the generated Swift package floor to iOS 13.

set -e

echo "🔧 Pre-build: Ensuring iOS CocoaPods dependencies are synced..."

# Get the directory where this script is located (should be project root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Never run a Flutter command here. Plugin injection rewrites
# ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift
# at Flutter's default .iOS("13.0"), and only `flutter build ios` / `flutter run`
# raise it back to 16.0 -- an Xcode build never does, so every Xcode build would
# fail on "requires minimum platform version 16.0 ... but this target supports 13".
# See .claude/rules/ios_build_troubleshooting.md, Cause 3.

# Navigate to iOS directory
cd ios

# Set environment for CocoaPods to avoid Ruby issues
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Find CocoaPods command
POD_CMD=""
if command -v pod >/dev/null 2>&1; then
    POD_CMD="pod"
elif [ -f "/opt/homebrew/bin/pod" ]; then
    POD_CMD="/opt/homebrew/bin/pod"
elif [ -f "/usr/local/bin/pod" ]; then
    POD_CMD="/usr/local/bin/pod"
else
    echo "❌ ERROR: CocoaPods not found!"
    echo "   Please install: sudo gem install cocoapods"
    exit 1
fi

# Ensure we use the correct Ruby environment (rbenv if available)
if [ -d "$HOME/.rbenv" ]; then
    export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init -)"
fi

# Check if CocoaPods needs to be installed or updated
if [ ! -f "Pods/Manifest.lock" ] || [ ! -d "Pods" ]; then
    echo "⚠️  CocoaPods not found, running pod install..."
    "$POD_CMD" install --verbose
elif [ "Podfile.lock" -nt "Pods/Manifest.lock" ]; then
    echo "⚠️  Podfile.lock is newer than Manifest.lock, running pod install..."
    "$POD_CMD" install --verbose
else
    echo "✅ CocoaPods dependencies are up to date"
fi

echo "✅ Pre-build iOS setup complete!"
