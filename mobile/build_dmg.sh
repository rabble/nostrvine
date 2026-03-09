#!/bin/bash
# ABOUTME: Creates a signed DMG for macOS distribution with Developer ID certificate
# ABOUTME: Produces a distributable DMG that users can download and install directly

set -e

echo "🖥️  Building macOS DMG for Distribution..."

# Navigate to project root
cd "$(dirname "$0")"

# Configuration
APP_NAME="Divine"
BUNDLE_ID="com.openvine.divine"
BUILD_DIR="build/macos/Build/Products/Release"
DMG_DIR="build/dmg"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
FINAL_DMG="build/$APP_NAME-macOS-$(date +%Y%m%d-%H%M%S).dmg"

# Check if Developer ID certificate is available
echo "🔐 Checking for Developer ID certificate..."
CERT_NAME=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed -n 's/.*"\(.*\)"/\1/p')

if [ -z "$CERT_NAME" ]; then
    echo "❌ No Developer ID Application certificate found!"
    echo "   Please install a valid Developer ID certificate from Apple Developer portal."
    echo "   Certificates & Identifiers → Certificates → Create (+) → Developer ID Application"
    exit 1
fi

echo "✅ Found certificate: $CERT_NAME"

# Step 1: Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "$BUILD_DIR"
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"

# Step 2: Reset camera permissions
echo "🔐 Resetting camera permissions for fresh build..."
tccutil reset Camera "$BUNDLE_ID" 2>/dev/null || true

# Step 3: Install dependencies
echo "📦 Installing dependencies..."
flutter pub get

cd macos
pod install
cd ..

# Step 4: Build release version
echo "🚀 Building macOS release app..."
flutter build macos --release

# Step 5: Verify app exists
if [ ! -d "$APP_PATH" ]; then
    echo "❌ App not found at $APP_PATH"
    exit 1
fi

echo "✅ App built successfully at $APP_PATH"

# Step 6: Sign the app with Developer ID for distribution
echo "🔏 Signing app with Developer ID for notarization..."
codesign --force --deep --sign "$CERT_NAME" \
         --options runtime \
         --timestamp \
         --entitlements macos/Runner/Release.entitlements \
         "$APP_PATH"

if [ $? -ne 0 ]; then
    echo "❌ Code signing failed!"
    exit 1
fi

# Verify the signature
echo "🔍 Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --type execute --verbose=4 "$APP_PATH" 2>&1 | grep "accepted" || {
    echo "⚠️  App signature may not be accepted by Gatekeeper"
}

# Step 7: Create DMG staging directory
echo "📦 Preparing DMG contents..."
cp -R "$APP_PATH" "$DMG_DIR/"

# Create Applications symlink for easy installation
ln -s /Applications "$DMG_DIR/Applications"

# Optional: Add background and custom icon (if available)
if [ -f "assets/dmg_background.png" ]; then
    mkdir -p "$DMG_DIR/.background"
    cp "assets/dmg_background.png" "$DMG_DIR/.background/background.png"
fi

# Step 8: Create DMG
echo "💿 Creating DMG..."

# Remove any existing temp DMG
rm -f "$FINAL_DMG.temp.dmg"

# Create temporary DMG
hdiutil create -volname "$APP_NAME" \
               -srcfolder "$DMG_DIR" \
               -ov \
               -format UDRW \
               "$FINAL_DMG.temp.dmg"

# Mount the DMG to customize it
MOUNT_DIR=$(hdiutil attach "$FINAL_DMG.temp.dmg" | grep Volumes | sed 's/.*\/Volumes/\/Volumes/')

# Customize DMG appearance with AppleScript
echo "🎨 Customizing DMG appearance..."
cat > /tmp/dmg_setup.applescript << EOF
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {100, 100, 600, 400}
        set position of item "$APP_NAME.app" of container window to {100, 100}
        set position of item "Applications" of container window to {400, 100}
        update without registering applications
        close
    end tell
end tell
EOF

osascript /tmp/dmg_setup.applescript 2>/dev/null || {
    echo "⚠️  Could not customize DMG appearance (non-critical)"
}

# Unmount
hdiutil detach "$MOUNT_DIR" 2>/dev/null || true

# Convert to final compressed DMG
echo "🗜️  Compressing DMG..."
hdiutil convert "$FINAL_DMG.temp.dmg" \
                -format UDZO \
                -imagekey zlib-level=9 \
                -o "$FINAL_DMG"

# Clean up temp DMG
rm -f "$FINAL_DMG.temp.dmg"
rm -rf "$DMG_DIR"

# Step 9: Sign the DMG
echo "🔏 Signing DMG..."
codesign --force --sign "$CERT_NAME" "$FINAL_DMG"

# Step 10: Verify final DMG
echo "🔍 Verifying DMG signature..."
codesign --verify --verbose=2 "$FINAL_DMG"

# Get DMG size
DMG_SIZE=$(du -h "$FINAL_DMG" | cut -f1)

echo ""
echo "✅ DMG created successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📱 DMG: $FINAL_DMG"
echo "💾 Size: $DMG_SIZE"
echo "🔏 Signed with: $CERT_NAME"
echo ""

# Ask if user wants to notarize
read -p "🍎 Notarize this DMG with Apple? (Required for distribution) (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Check for stored credentials
    APPLE_ID="rabble@verse.app"
    TEAM_ID="GZCZBKH7MY"

    # Try to get password from keychain
    AC_PASSWORD=$(security find-generic-password -s "AC_PASSWORD" -w 2>/dev/null || echo "")

    if [ -z "$AC_PASSWORD" ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "⚠️  App-Specific Password Required"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "To notarize, you need an app-specific password from Apple:"
        echo ""
        echo "1. Go to: https://appleid.apple.com/account/manage"
        echo "2. Sign in with: $APPLE_ID"
        echo "3. In 'Sign-In and Security' → 'App-Specific Passwords'"
        echo "4. Click '+' to generate a new password"
        echo "5. Name it: 'macOS Notarization'"
        echo "6. Copy the generated password"
        echo ""
        read -p "Enter app-specific password (or press Enter to skip): " -s AC_PASSWORD
        echo ""

        if [ -n "$AC_PASSWORD" ]; then
            # Offer to save to keychain
            read -p "Save password to keychain for future builds? (y/N): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                security add-generic-password -a "$USER" -s "AC_PASSWORD" -w "$AC_PASSWORD" -U
                echo "✅ Password saved to keychain"
            fi
        fi
    else
        echo "✅ Using saved app-specific password from keychain"
    fi

    if [ -n "$AC_PASSWORD" ]; then
        echo ""
        echo "🔄 Submitting DMG for notarization..."
        echo "   (This may take 2-5 minutes)"

        NOTARIZE_OUTPUT=$(xcrun notarytool submit "$FINAL_DMG" \
            --apple-id "$APPLE_ID" \
            --team-id "$TEAM_ID" \
            --password "$AC_PASSWORD" \
            --wait 2>&1)

        if echo "$NOTARIZE_OUTPUT" | grep -q "status: Accepted"; then
            echo "✅ Notarization successful!"

            echo "📎 Stapling notarization ticket to DMG..."
            xcrun stapler staple "$FINAL_DMG"

            echo "🔍 Verifying notarized DMG..."
            spctl --assess --type open --context context:primary-signature -v "$FINAL_DMG" 2>&1

            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "✅ DMG is FULLY NOTARIZED and ready for distribution!"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "📱 DMG: $FINAL_DMG"
            echo "💾 Size: $DMG_SIZE"
            echo "🔐 Signed & Notarized"
            echo ""
            echo "Users can now download and install without Gatekeeper warnings!"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        else
            echo "❌ Notarization failed!"
            echo ""
            echo "$NOTARIZE_OUTPUT"
            echo ""
            echo "📱 DMG is signed but NOT notarized: $FINAL_DMG"
            echo "   Users will see Gatekeeper warnings when trying to install"
        fi
    else
        echo "⏭️  Skipping notarization"
        echo ""
        echo "📱 DMG: $FINAL_DMG"
        echo "⚠️  NOT notarized - users will see Gatekeeper warnings"
    fi
else
    echo "⏭️  Skipping notarization"
    echo ""
    echo "📱 DMG: $FINAL_DMG"
    echo "⚠️  NOT notarized - users will see Gatekeeper warnings"
    echo ""
    echo "To notarize later, run:"
    echo "  xcrun notarytool submit \"$FINAL_DMG\" \\"
    echo "      --apple-id \"$APPLE_ID\" \\"
    echo "      --team-id \"$TEAM_ID\" \\"
    echo "      --password \"<app-specific-password>\" \\"
    echo "      --wait"
    echo "  xcrun stapler staple \"$FINAL_DMG\""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
