#!/bin/bash
# ABOUTME: Script to notarize the OpenVine macOS app for distribution
# ABOUTME: Run this after building to submit the DMG to Apple for notarization

set -e

# Configuration
APP_DMG="/Users/rabble/code/experiments/nostrvine/mobile/build/macos/Build/Products/Release/OpenVine-0.0.1.dmg"
BUNDLE_ID="co.openvine.app"
APPLE_ID="${APPLE_ID:-rabble@verse.app}"
TEAM_ID="GZCZBKH7MY"

echo "🍎 Starting notarization process for OpenVine..."

# Check if DMG exists
if [ ! -f "$APP_DMG" ]; then
    echo "❌ DMG file not found: $APP_DMG"
    echo "Please run 'flutter build macos --release' first"
    exit 1
fi

# Check if xcrun notarytool is available
if ! command -v xcrun &> /dev/null; then
    echo "❌ Xcode command line tools not found"
    echo "Please install Xcode command line tools"
    exit 1
fi

echo "📦 DMG file: $APP_DMG"
echo "🆔 Bundle ID: $BUNDLE_ID"
echo "👤 Apple ID: $APPLE_ID"
echo "🏢 Team ID: $TEAM_ID"

# Submit for notarization
echo ""
echo "🚀 Submitting to Apple for notarization..."
echo "Note: You'll need to enter your app-specific password when prompted"
echo ""

# Use notarytool (requires Xcode 13+)
xcrun notarytool submit "$APP_DMG" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --wait

echo ""
echo "✅ Notarization complete!"
echo ""
echo "📦 Your signed and notarized DMG is ready for distribution:"
echo "   $APP_DMG"
echo ""
echo "🔍 To verify notarization:"
echo "   spctl -a -t open --context context:primary-signature \"$APP_DMG\""
echo ""
echo "📱 Users can now download and install OpenVine without security warnings!"