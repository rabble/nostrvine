#!/usr/bin/env bash
# ABOUTME: Builds an Android APK with a build number synced to the latest Codemagic CI build.
# ABOUTME: Queries Codemagic API to avoid version code conflicts when sideloading.
#
# Usage:
#   ./scripts/build_android.sh                    # Release APK
#   ./scripts/build_android.sh --debug             # Debug APK
#   ./scripts/build_android.sh --dart-define=FOO=1  # Pass extra flutter args
#
# Setup:
#   1. Get your Codemagic API token:
#      Codemagic UI > Teams > Personal Account > Integrations > Codemagic API > Show
#   2. Get your App ID from the Codemagic project URL
#   3. Set them in mobile/.env:
#        CM_API_TOKEN=your-token-here
#        CM_APP_ID=your-app-id-here

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

# --- Load .env if present ---
if [[ -f "$PROJECT_DIR/.env" ]]; then
  # Export vars from .env, skipping comments and blank lines
  set -a
  # shellcheck disable=SC1091
  source <(grep -v '^\s*#' "$PROJECT_DIR/.env" | grep -v '^\s*$')
  set +a
fi

# --- Parse args ---
BUILD_MODE="--release"
EXTRA_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --debug)
      BUILD_MODE="--debug"
      ;;
    --profile)
      BUILD_MODE="--profile"
      ;;
    *)
      EXTRA_ARGS+=("$arg")
      ;;
  esac
done

# --- Read pubspec build number as floor ---
PUBSPEC_BUILD_NUM=$(grep '^version:' pubspec.yaml | sed 's/.*+//')
if ! [[ "$PUBSPEC_BUILD_NUM" =~ ^[0-9]+$ ]]; then
  echo "Warning: Could not parse build number from pubspec.yaml, defaulting to 1"
  PUBSPEC_BUILD_NUM=1
fi

# --- Query Codemagic for latest build index ---
CM_BUILD_NUM=""

if [[ -n "${CM_API_TOKEN:-}" && -n "${CM_APP_ID:-}" ]]; then
  echo "Querying Codemagic for latest build index..."

  API_RESPONSE=$(curl -s --max-time 10 \
    -H "x-auth-token: $CM_API_TOKEN" \
    "https://api.codemagic.io/builds?appId=$CM_APP_ID" 2>/dev/null) || true

  if [[ -n "$API_RESPONSE" ]]; then
    # Check if jq is available
    if command -v jq &>/dev/null; then
      LATEST_INDEX=$(echo "$API_RESPONSE" | jq '[.builds[].index // 0] | max // 0' 2>/dev/null) || true

      if [[ -n "$LATEST_INDEX" && "$LATEST_INDEX" =~ ^[0-9]+$ && "$LATEST_INDEX" -gt 0 ]]; then
        CM_BUILD_NUM=$((LATEST_INDEX + 1))
        echo "Latest Codemagic build index: $LATEST_INDEX"
      else
        echo "Warning: Could not parse build index from Codemagic API response"
      fi
    else
      echo "Warning: jq not installed. Install with: brew install jq"
      echo "Falling back to pubspec.yaml build number."
    fi
  else
    echo "Warning: Codemagic API request failed (no response)"
  fi
else
  echo "Note: CM_API_TOKEN and/or CM_APP_ID not set."
  echo "  Set them in mobile/.env or export them to sync with Codemagic build numbers."
  echo "  See mobile/.env.example for details."
fi

# --- Pick the higher build number ---
if [[ -n "$CM_BUILD_NUM" && "$CM_BUILD_NUM" -gt "$PUBSPEC_BUILD_NUM" ]]; then
  BUILD_NUM=$CM_BUILD_NUM
else
  BUILD_NUM=$PUBSPEC_BUILD_NUM
  if [[ -z "$CM_BUILD_NUM" ]]; then
    echo "Using pubspec.yaml build number as fallback."
  fi
fi

echo ""
echo "Building APK with:"
echo "  Build number: $BUILD_NUM"
echo "  Mode: $BUILD_MODE"
echo ""

flutter build apk "$BUILD_MODE" --build-number="$BUILD_NUM" "${EXTRA_ARGS[@]}"

echo ""
echo "Done! Build number: $BUILD_NUM"
