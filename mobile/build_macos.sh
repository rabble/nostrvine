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
fi

echo "✅ macOS build complete!"
