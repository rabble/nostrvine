#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# Maestro iOS Simulator smoke runner (portable, verbose)
# Location: maestro/scripts/ui_smoke_ios.sh
#
# Behavior:
#  - Ensures an iOS simulator is booted (defaults to iPhone 16 Pro)
#  - Installs ./maestro/Runner.app onto that simulator
#  - Verifies installation using BUNDLE_ID (co.openvine.app)
#  - Runs Maestro suite: ./maestro/suites/smoke.yml
# ------------------------------------------------------------

# -----------------------------
# Helpers (LOGS -> stderr)
# -----------------------------
fail() { echo "❌ $1" >&2; exit 1; }
info() { echo "ℹ️  $1" >&2; }
ok()   { echo "✅ $1" >&2; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing '$1'. ${2:-}"
}

# -----------------------------
# Paths (location independent)
# -----------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAESTRO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

SUITE_PATH="${MAESTRO_DIR}/suites/smoke.yml"
APP_PATH="${MAESTRO_DIR}/Runner.app"
APP_INFO_PLIST="${APP_PATH}/Info.plist"

# -----------------------------
# Config
# -----------------------------
IOS_SIM_DEVICE="iPhone 16 Pro"
MAESTRO_CLI="maestro"
BUNDLE_ID="co.openvine.app"

# -----------------------------
# Preconditions
# -----------------------------
info "Validating prerequisites..."
require_cmd xcrun "Install Xcode + Command Line Tools."
require_cmd plutil "plutil should exist on macOS."
require_cmd "${MAESTRO_CLI}" "Install Maestro: brew install maestro"
[[ -f "${SUITE_PATH}" ]] || fail "Suite not found: ${SUITE_PATH}"
[[ -d "${APP_PATH}" ]] || fail "Runner.app not found at: ${APP_PATH}"
[[ -f "${APP_INFO_PLIST}" ]] || fail "Info.plist not found at: ${APP_INFO_PLIST}"
ok "Prerequisites look good"

info "Suite path: ${SUITE_PATH}"
info "Target simulator device name: ${IOS_SIM_DEVICE}"
info "App bundle to install: ${APP_PATH}"
info "Bundle id expected: ${BUNDLE_ID}"

# -----------------------------
# Validate Runner.app is a SIMULATOR build
# -----------------------------
info "Validating Runner.app is a Simulator build..."
SUPPORTED_PLATFORMS="$(/usr/libexec/PlistBuddy -c "Print :CFBundleSupportedPlatforms" "${APP_INFO_PLIST}" 2>/dev/null || true)"

# CFBundleSupportedPlatforms is typically an array like:
#   Array {
#     0 = iPhoneSimulator
#   }
if echo "${SUPPORTED_PLATFORMS}" | grep -q "iPhoneSimulator"; then
  ok "Runner.app supports iPhoneSimulator ✅"
else
  info "CFBundleSupportedPlatforms from Runner.app Info.plist:"
  echo "${SUPPORTED_PLATFORMS:-"(not found)"}" >&2
  fail "Runner.app does NOT look like a Simulator build.

Fix:
  Build a simulator app:
    flutter build ios --simulator --debug

  Then copy:
    build/ios/iphonesimulator/Runner.app
  into:
    maestro/Runner.app
"
fi

# -----------------------------
# Simulator helpers
# -----------------------------
get_booted_udid() {
  local json
  json="$(xcrun simctl list devices booted -j 2>/dev/null || true)"
  [[ -n "${json}" ]] || { echo ""; return 0; }

  echo "${json}" \
    | plutil -convert xml1 -o - - 2>/dev/null \
    | awk -F'[<>]' '
        /<key>udid<\/key>/ {
          getline;
          gsub(/.*<string>|<\/string>.*/, "", $0);
          print $0;
          exit
        }'
}

find_device_udid_by_name() {
  local name="$1"
  local json
  json="$(xcrun simctl list devices -j 2>/dev/null || true)"
  [[ -n "${json}" ]] || { echo ""; return 0; }

  echo "${json}" \
    | plutil -convert xml1 -o - - 2>/dev/null \
    | awk -v target="${name}" '
      BEGIN { inDevice=0; nameMatch=0; udid=""; available=0 }
      /<dict>/ { inDevice=1; nameMatch=0; udid=""; available=0 }
      /<\/dict>/ {
        if (inDevice && nameMatch && available && udid != "") { print udid; exit }
        inDevice=0
      }
      inDevice && /<key>isAvailable<\/key>/ { getline; if ($0 ~ /<true\/>/) available=1 }
      inDevice && /<key>name<\/key>/ { getline; if ($0 ~ "<string>" target "</string>") nameMatch=1 }
      inDevice && /<key>udid<\/key>/ { getline; gsub(/.*<string>|<\/string>.*/, "", $0); udid=$0 }
    '
}

print_simulator_info() {
  local udid="$1"
  info "Simulator details (UDID: ${udid}):"

  local json
  json="$(xcrun simctl list devices -j 2>/dev/null || true)"
  [[ -n "${json}" ]] || { info "  • (unable to load simctl devices json)"; return 0; }

  echo "${json}" \
    | plutil -convert xml1 -o - - 2>/dev/null \
    | awk -v target="$udid" '
      /<dict>/ { inDict=0 }
      /<key>udid<\/key>/ {
        getline;
        gsub(/.*<string>|<\/string>.*/, "", $0);
        if ($0 == target) inDict=1
      }
      inDict && /<key>name<\/key>/ { getline; gsub(/.*<string>|<\/string>.*/, "", $0); print "  • Name: " $0 }
      inDict && /<key>state<\/key>/ { getline; gsub(/.*<string>|<\/string>.*/, "", $0); print "  • State: " $0 }
      inDict && /<key>runtime<\/key>/ { getline; gsub(/.*<string>|<\/string>.*/, "", $0); print "  • Runtime: " $0 }
    ' >&2
}

boot_simulator_if_needed() {
  local udid
  udid="$(get_booted_udid)"

  if [[ -n "${udid}" ]]; then
    ok "Found an already booted simulator"
    print_simulator_info "${udid}"
    echo "${udid}"
    return 0
  fi

  info "No booted simulator found."
  info "Attempting to boot simulator: ${IOS_SIM_DEVICE}"

  udid="$(find_device_udid_by_name "${IOS_SIM_DEVICE}")"
  [[ -n "${udid}" ]] || fail "Could not find an available simulator named '${IOS_SIM_DEVICE}'. Run: xcrun simctl list devices"

  info "Booting simulator UDID: ${udid}"
  xcrun simctl boot "${udid}" || true
  open -a Simulator >/dev/null 2>&1 || true

  sleep 2

  local booted
  booted="$(get_booted_udid)"
  [[ -n "${booted}" ]] || fail "Simulator failed to boot."

  ok "Simulator booted successfully"
  print_simulator_info "${booted}"
  echo "${booted}"
}

install_app_on_simulator() {
  local udid="$1"

  info "Installing app on simulator..."
  info "Best-effort uninstall of existing app (if present): ${BUNDLE_ID}"
  xcrun simctl uninstall "${udid}" "${BUNDLE_ID}" >/dev/null 2>&1 || true

  info "Install command: xcrun simctl install ${udid} ${APP_PATH}"
  # IMPORTANT: do NOT suppress output — we want errors to be visible
  xcrun simctl install "${udid}" "${APP_PATH}" || fail "Failed to install Runner.app onto simulator."
  ok "Install step completed"
}

verify_app_installed() {
  local udid="$1"
  info "Verifying app installation..."
  info "Bundle id: ${BUNDLE_ID}"

  if xcrun simctl get_app_container "${udid}" "${BUNDLE_ID}" >/dev/null 2>&1; then
    ok "App is installed on the simulator"
    return 0
  fi

  info "App not found under bundle id '${BUNDLE_ID}'. Dumping installed apps (filtered):"
  xcrun simctl listapps "${udid}" 2>/dev/null \
    | egrep -i "CFBundle(DisplayName|Identifier|Name)" \
    | head -n 200 >&2 || true

  fail "Installation verification failed.
This usually means:
  • Runner.app bundle id is not '${BUNDLE_ID}', OR
  • install failed silently earlier (now visible above)."
}

# -----------------------------
# Main
# -----------------------------
info "Resolving iOS Simulator..."
SIM_UDID="$(boot_simulator_if_needed)"
ok "Using simulator UDID: ${SIM_UDID}"

install_app_on_simulator "${SIM_UDID}"
verify_app_installed "${SIM_UDID}"

info "Running Maestro suite..."
info "Command: ${MAESTRO_CLI} test ${SUITE_PATH}"
"${MAESTRO_CLI}" test "${SUITE_PATH}"

ok "Maestro smoke suite completed successfully 🎉"
