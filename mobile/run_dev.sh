#!/bin/bash
# ABOUTME: Development runner script for local testing
# ABOUTME: Simplifies running the app with proper environment configuration and auto-detects iOS devices

set -e

# Default to Chrome if no device specified
DEVICE_ARG="${1:-chrome}"
BUILD_MODE="${2:-debug}"

# Smart device resolution
resolve_device() {
    local requested_device="$1"

    case "$requested_device" in
        "ios"|"iphone")
            echo "📱 Looking for iOS devices..." >&2
            # Get the first iOS device ID
            local ios_device_id=$(flutter devices --machine | jq -r '.[] | select(.targetPlatform == "ios") | .id' | head -1)

            if [ -n "$ios_device_id" ] && [ "$ios_device_id" != "null" ]; then
                echo "📱 Found iOS device: $ios_device_id" >&2
                echo "$ios_device_id"
            else
                echo "❌ No iOS devices found. Available devices:" >&2
                flutter devices >&2
                exit 1
            fi
            ;;
        "android")
            echo "🤖 Looking for Android devices..." >&2
            local android_device_id=$(flutter devices --machine | jq -r '.[] | select(.targetPlatform | startswith("android")) | .id' | head -1)

            if [ -n "$android_device_id" ] && [ "$android_device_id" != "null" ]; then
                echo "🤖 Found Android device: $android_device_id" >&2
                echo "$android_device_id"
            else
                echo "❌ No Android devices found. Available devices:" >&2
                flutter devices >&2
                exit 1
            fi
            ;;
        "macos"|"desktop")
            echo "macos"
            ;;
        "chrome"|"web")
            echo "chrome"
            ;;
        *)
            # Assume it's already a specific device ID
            echo "$requested_device"
            ;;
    esac
}

DEVICE=$(resolve_device "$DEVICE_ARG")

# Reset camera permissions for macOS builds to prevent stuck TCC state
if [ "$DEVICE" = "macos" ]; then
    echo "🔐 Resetting camera permissions for macOS..."
    tccutil reset Camera com.openvine.divine 2>/dev/null || true
fi

echo "🚀 Running OpenVine in $BUILD_MODE mode on $DEVICE"

# Load Zendesk credentials from .env if it exists
DART_DEFINES=""
if [ -f .env ]; then
    echo "📦 Loading environment from .env..."
    source .env

    if [ -n "$ZENDESK_APP_ID" ]; then
        DART_DEFINES="$DART_DEFINES --dart-define=ZENDESK_APP_ID=$ZENDESK_APP_ID"
    fi

    if [ -n "$ZENDESK_CLIENT_ID" ]; then
        DART_DEFINES="$DART_DEFINES --dart-define=ZENDESK_CLIENT_ID=$ZENDESK_CLIENT_ID"
    fi

    if [ -n "$ZENDESK_URL" ]; then
        DART_DEFINES="$DART_DEFINES --dart-define=ZENDESK_URL=$ZENDESK_URL"
    fi

    if [ -n "$ZENDESK_API_TOKEN" ]; then
        DART_DEFINES="$DART_DEFINES --dart-define=ZENDESK_API_TOKEN=$ZENDESK_API_TOKEN"
    fi
fi

flutter run -d "$DEVICE" --$BUILD_MODE $DART_DEFINES