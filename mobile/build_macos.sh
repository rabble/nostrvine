#!/bin/bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: ./build_macos.sh [debug|release] [options]

Positional:
  debug      - Build debug mode (default)
  release    - Build release + xcode archive export prompt

Options:
  --codegen         - Force running build_runner before build
  --no-codegen      - Skip build_runner even for release
  --pod-reset       - Remove macos/Pods and macos/Podfile.lock before build
  --no-pub-get      - Skip flutter pub get
  --no-pod-install  - Skip pod install checks
  --help            - Show this help

Performance note:
  Debug builds skip codegen by default. Use --codegen only when you touched
  generated-code sources.
EOF
}

BUILD_MODE="debug"
CODEGEN_MODE="auto"
PUB_GET=true
POD_INSTALL_MODE="auto"
FORCE_POD_RESET=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        debug|release)
            BUILD_MODE="$1"
            shift
            ;;
        --codegen)
            CODEGEN_MODE="always"
            shift
            ;;
        --no-codegen)
            CODEGEN_MODE="never"
            shift
            ;;
        --pod-reset)
            FORCE_POD_RESET=true
            shift
            ;;
        --no-pub-get)
            PUB_GET=false
            shift
            ;;
        --no-pod-install)
            POD_INSTALL_MODE="never"
            shift
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
done

if [[ "$BUILD_MODE" == "release" && "$CODEGEN_MODE" == "auto" ]]; then
    CODEGEN_MODE="always"
fi

echo "🖥️  Building macOS App..."
cd "$(dirname "$0")"

DEBUG_APP_PATH="build/macos/Build/Products/Debug/Divine.app"
RELEASE_APP_PATH="build/macos/Build/Products/Release/Divine.app"
MACOS_BUNDLE_ID="${MACOS_BUNDLE_ID:-co.openvine.app}"

find_macos_signing_identity() {
    if [[ -n "${MACOS_SIGNING_IDENTITY:-}" ]]; then
        echo "$MACOS_SIGNING_IDENTITY"
        return 0
    fi

    local hash
    local display_identity
    local tmp_file
    local signature_details
    local team_id

    while IFS='|' read -r hash display_identity; do
        [[ -n "$hash" ]] || continue
        tmp_file="$(mktemp "${TMPDIR:-/tmp}/divine-codesign-probe.XXXXXX")"
        printf 'codesign probe\n' > "$tmp_file"

        if codesign --force --sign "$hash" "$tmp_file" >/dev/null 2>&1; then
            signature_details="$(codesign -dvvv "$tmp_file" 2>&1)"
            team_id="$(sed -n 's/^TeamIdentifier=//p' <<<"$signature_details" | head -1)"
            rm -f "$tmp_file"

            if [[ -n "$team_id" && "$team_id" != "not set" ]]; then
                echo "$hash|$display_identity|$team_id"
                return 0
            fi
        else
            rm -f "$tmp_file"
        fi
    done < <(
        security find-identity -v -p codesigning \
            | sed -n 's/^[[:space:]]*[0-9]*)[[:space:]]*\([A-F0-9]\{40\}\)[[:space:]]*"\(Apple Development:.*\)"/\1|\2/p'
    )

    return 1
}

team_id_from_identity() {
    local identity="$1"
    local detected_team_id

    if [[ "$identity" == *"|"*"|"* ]]; then
        detected_team_id="${identity##*|}"
        if [[ -n "$detected_team_id" ]]; then
            echo "$detected_team_id"
            return 0
        fi
    fi

    if [[ -n "${MACOS_DEVELOPMENT_TEAM:-}" ]]; then
        echo "$MACOS_DEVELOPMENT_TEAM"
        return 0
    fi

    echo "❌ Could not infer Apple Team ID from signing identity: $identity" >&2
    echo "   Set MACOS_DEVELOPMENT_TEAM=<TEAMID> and rerun." >&2
    return 1
}

expand_macos_entitlements() {
    local source_plist="$1"
    local output_plist="$2"
    local team_id="$3"
    local bundle_id="$4"

    sed \
        -e "s/\\\$(AppIdentifierPrefix)/${team_id}./g" \
        -e "s/\\\$(CFBundleIdentifier)/${bundle_id}/g" \
        "$source_plist" > "$output_plist"
}

verify_macos_keychain_entitlements() {
    local app_path="$1"
    local expected_access_group="$2"
    local signature_details
    local entitlements

    signature_details="$(codesign -dvvv "$app_path" 2>&1)"
    if grep -q 'Signature=adhoc' <<<"$signature_details"; then
        echo "❌ macOS app is still ad-hoc signed; Keychain will fail with OSStatus -34018." >&2
        return 1
    fi
    if grep -q 'TeamIdentifier=not set' <<<"$signature_details"; then
        echo "❌ macOS app has no TeamIdentifier; Keychain entitlements are not usable." >&2
        return 1
    fi

    entitlements="$(codesign -d --entitlements :- "$app_path" 2>&1)"
    if ! grep -q 'keychain-access-groups' <<<"$entitlements"; then
        echo "❌ macOS app is missing keychain-access-groups entitlement." >&2
        return 1
    fi
    if ! grep -q "$expected_access_group" <<<"$entitlements"; then
        echo "❌ macOS app keychain entitlement does not include $expected_access_group." >&2
        return 1
    fi

    codesign --verify --deep --strict --verbose=2 "$app_path"
}

verify_macos_embedded_provisioning_profile() {
    local app_path="$1"

    if [[ -f "$app_path/Contents/embedded.provisionprofile" ]] || \
       [[ -f "$app_path/Contents/embedded.mobileprovision" ]]; then
        return 0
    fi

    echo "❌ macOS app is missing an embedded provisioning profile." >&2
    echo "   Restricted entitlements will be rejected by AMFI at launch." >&2
    return 1
}

sign_macos_app() {
    local app_path="$1"
    local build_mode="$2"
    local source_entitlements
    local identity
    local signing_identity
    local display_identity
    local team_id
    local expanded_entitlements
    local expected_access_group

    if [[ ! -d "$app_path" ]]; then
        echo "❌ macOS app not found at $app_path" >&2
        return 1
    fi

    if [[ "$build_mode" == "release" ]]; then
        source_entitlements="macos/Runner/Release.entitlements"
    else
        source_entitlements="macos/Runner/DebugProfile.entitlements"
    fi

    identity="$(find_macos_signing_identity)"
    if [[ -z "$identity" ]]; then
        echo "❌ No Apple Development codesigning identity found." >&2
        echo "   Install a local Apple Development certificate or set MACOS_SIGNING_IDENTITY." >&2
        return 1
    fi

    team_id="$(team_id_from_identity "$identity")"
    if [[ "$identity" == *"|"* ]]; then
        signing_identity="${identity%%|*}"
        display_identity="${identity#*|}"
        display_identity="${display_identity%|*}"
    else
        signing_identity="$identity"
        display_identity="$identity"
    fi

    expected_access_group="${team_id}.${MACOS_BUNDLE_ID}"
    expanded_entitlements="$(mktemp "${TMPDIR:-/tmp}/divine-macos-entitlements.XXXXXX")"
    expand_macos_entitlements "$source_entitlements" "$expanded_entitlements" "$team_id" "$MACOS_BUNDLE_ID"

    echo "🔏 Signing macOS app with identity: $display_identity"
    echo "🔐 Keychain access group: $expected_access_group"
    codesign --force --deep --sign "$signing_identity" \
        --entitlements "$expanded_entitlements" \
        "$app_path"

    rm -f "$expanded_entitlements"
    verify_macos_keychain_entitlements "$app_path" "$expected_access_group"
}

xcodebuild_signed_macos_app() {
    local build_mode="$1"
    local configuration
    local app_path
    local identity
    local team_id
    local expected_access_group
    local symroot

    if [[ "$build_mode" == "release" ]]; then
        configuration="Release"
        app_path="$RELEASE_APP_PATH"
    else
        configuration="Debug"
        app_path="$DEBUG_APP_PATH"
    fi

    identity="$(find_macos_signing_identity)"
    if [[ -z "$identity" ]]; then
        echo "❌ No Apple Development codesigning identity found." >&2
        echo "   Install a local Apple Development certificate or set MACOS_SIGNING_IDENTITY." >&2
        return 1
    fi

    team_id="$(team_id_from_identity "$identity")"
    expected_access_group="${team_id}.${MACOS_BUNDLE_ID}"
    symroot="$(pwd)/build/macos/Build/Products"

    echo "🔏 Building signed macOS $build_mode app with Xcode automatic signing..."
    echo "🔐 Keychain access group: $expected_access_group"
    (
        cd macos
        xcodebuild -workspace Runner.xcworkspace \
                   -scheme Runner \
                   -configuration "$configuration" \
                   -destination platform=macOS \
                   SYMROOT="$symroot" \
                   CODE_SIGNING_ALLOWED=YES \
                   CODE_SIGNING_REQUIRED=YES \
                   CODE_SIGN_STYLE=Automatic \
                   DEVELOPMENT_TEAM="$team_id" \
                   PRODUCT_BUNDLE_IDENTIFIER="$MACOS_BUNDLE_ID" \
                   -allowProvisioningUpdates \
                   build
    )

    verify_macos_keychain_entitlements "$app_path" "$expected_access_group"
    verify_macos_embedded_provisioning_profile "$app_path"
}

# Reset camera permissions to fix stuck TCC state
echo "🔐 Resetting camera permissions for fresh build..."
tccutil reset Camera com.openvine.divine 2>/dev/null || true
echo "✅ Camera permissions reset (will need to re-grant on first launch)"

DART_DEFINES=""
if [[ -f .env ]]; then
    echo "📦 Loading environment from .env..."
    source .env

    if [[ -n "${ZENDESK_APP_ID:-}" ]]; then
        DART_DEFINES="$DART_DEFINES --dart-define=ZENDESK_APP_ID=$ZENDESK_APP_ID"
    fi

    if [[ -n "${ZENDESK_CLIENT_ID:-}" ]]; then
        DART_DEFINES="$DART_DEFINES --dart-define=ZENDESK_CLIENT_ID=$ZENDESK_CLIENT_ID"
    fi

    if [[ -n "${ZENDESK_URL:-}" ]]; then
        DART_DEFINES="$DART_DEFINES --dart-define=ZENDESK_URL=$ZENDESK_URL"
    fi

    if [[ -n "${DEFAULT_ENV:-}" ]]; then
        DART_DEFINES="$DART_DEFINES --dart-define=DEFAULT_ENV=$DEFAULT_ENV"
    fi
fi

PUB_HASH_FILE=".dart_tool/.last_pub_get_hash"
current_pub_hash() {
    if [[ -f pubspec.yaml ]]; then
        cat pubspec.yaml pubspec.lock 2>/dev/null | shasum -a 256 | awk '{print $1}'
    fi
}
pub_get_is_fresh() {
    [[ -f .dart_tool/package_config.json ]] || return 1
    [[ -f "$PUB_HASH_FILE" ]] || return 1
    [[ "$(cat "$PUB_HASH_FILE" 2>/dev/null)" == "$(current_pub_hash)" ]] || return 1
    return 0
}
mark_pub_get_fresh() {
    mkdir -p .dart_tool
    current_pub_hash > "$PUB_HASH_FILE"
}

if [[ "$PUB_GET" == "true" ]]; then
    if pub_get_is_fresh; then
        echo "✅ Dependencies up to date (pubspec unchanged) — skipping pub get"
    elif [[ "$CODEGEN_MODE" == "always" ]]; then
        echo "⏭️  Skipping standalone pub get — build_runner will resolve once"
    else
        echo "📦 Getting Flutter dependencies..."
        flutter pub get
        mark_pub_get_fresh
    fi
fi

CODEGEN_MARKER=".dart_tool/.last_codegen_marker"
codegen_inputs_changed() {
    [[ -f "$CODEGEN_MARKER" ]] || return 0
    local newer
    newer=$(find lib pubspec.lock \
        -type f \
        \( -name '*.dart' -o -name 'pubspec.lock' \) \
        ! -name '*.g.dart' \
        ! -name '*.freezed.dart' \
        ! -name '*.mocks.dart' \
        -newer "$CODEGEN_MARKER" \
        -print -quit 2>/dev/null)
    [[ -n "$newer" ]]
}

if [[ "$CODEGEN_MODE" == "always" ]]; then
    if codegen_inputs_changed; then
        echo "🔧 Generating code with build_runner..."
        dart run build_runner build --delete-conflicting-outputs
        mkdir -p .dart_tool && touch "$CODEGEN_MARKER"
        mark_pub_get_fresh
    else
        echo "✅ Codegen up to date (no input changes since last build)"
    fi
else
    echo "⏭️  Skipping build_runner for $BUILD_MODE (use --codegen if needed)"
fi

if [[ "$POD_INSTALL_MODE" != "never" ]]; then
    echo "🏗️  Preparing CocoaPods..."
    cd macos

    if [[ "$FORCE_POD_RESET" == "true" ]]; then
        echo "🧹 Pod reset requested - removing Pods and Podfile.lock"
        rm -rf Pods
        rm -f Podfile.lock
    fi

    if [[ ! -d Pods ]] || [[ ! -f Podfile.lock ]] || [[ ! -f Pods/Manifest.lock ]]; then
        echo "📦 Running pod install..."
        pod install
    elif ! diff "Podfile.lock" "Pods/Manifest.lock" >/dev/null 2>&1; then
        echo "📦 Pod state changed, running pod install..."
        pod install
    else
        echo "✅ Pod install already up to date"
    fi

    cd ..
else
    echo "⏭️  Skipping pod install checks"
fi

echo "🚀 Building macOS app..."
if [[ "$BUILD_MODE" == "release" ]]; then
    echo "🏗️  Building Flutter macOS release..."
    flutter build macos --release $DART_DEFINES
    sign_macos_app "$RELEASE_APP_PATH" "release"

    echo "📦 Creating Xcode archive..."
    cd macos
    
    ARCHIVE_NAME="Runner-macOS-$(date +%Y-%m-%d-%H%M%S).xcarchive"
    ORGANIZER_PATH="$HOME/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)"
    
    mkdir -p "$ORGANIZER_PATH"
    
    xcodebuild -workspace Runner.xcworkspace \
               -scheme Runner \
               -configuration Release \
               -destination generic/platform=macOS \
               -archivePath "$ORGANIZER_PATH/$ARCHIVE_NAME" \
               archive
    
    if [ $? -eq 0 ]; then
        echo "✅ Archive created successfully!"
        echo "📱 Archive location: $ORGANIZER_PATH/$ARCHIVE_NAME"
        
        if pgrep -x "Xcode" >/dev/null; then
            echo "🔄 Refreshing Xcode Organizer..."
            osascript -e 'tell application "Xcode" to activate' 2>/dev/null || true
        fi
        
        echo "🚀 Archive is now available in Xcode Organizer for distribution!"
        echo "   • Open Xcode → Window → Organizer"
        echo "   • Select your archive and click 'Distribute App'"
        echo "   • Choose distribution method (Mac App Store, Developer ID, etc.)"
        
        echo ""
        read -p "📦 Would you like to export to PKG for Mac App Store distribution? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "📦 Exporting archive to PKG..."
            
            cat > build/ExportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
EOF
            
            # Export archive to PKG
            xcodebuild -exportArchive \
                       -archivePath "$ORGANIZER_PATH/$ARCHIVE_NAME" \
                       -exportOptionsPlist build/ExportOptions.plist \
                       -exportPath build/pkg
            
            if [ $? -eq 0 ]; then
                echo "✅ PKG export successful!"
                echo "📱 PKG location: $(pwd)/build/pkg/Runner.pkg"
                echo "🚀 Ready for Mac App Store upload via Xcode Organizer or Transporter!"
            else
                echo "❌ PKG export failed. Archive is still available in Organizer."
            fi
        fi
    else
        echo "❌ Archive creation failed!"
        exit 1
    fi
    
    cd ..
else
    flutter build macos --debug $DART_DEFINES
    xcodebuild_signed_macos_app "debug"
fi

echo "✅ macOS build complete!"
