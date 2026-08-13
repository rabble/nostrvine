#!/usr/bin/env bash
# Fails CI if a backend-host *default* (not a content URL) points off
# *.divine.video. Two surfaces are scanned:
#
#   A. app_config.dart `*BaseUrl` `defaultValue:` URLs.
#   B. .github/workflows `--dart-define=<KEY>URL=<url>` injects.
#
# A host passes iff it is `divine.video` or `*.divine.video`. Any other host
# must be listed in the ALLOWED allowlist below (tuple `surface|host`), which
# exists so a *knowingly* legacy default (e.g. a media/analytics endpoint that
# still lives on api.openvine.co until the server side migrates) can be exempted
# with a tracked reason instead of loosening the rule.
#
# Two-way invariant:
#   1. Scanned off-divine host NOT in ALLOWED  -> FAIL (catches a new legacy ref
#      or an existing default flipped to a non-divine host).
#   2. ALLOWED entry matching ZERO scanned occurrences -> FAIL (forces removal of
#      an exemption once the ref is migrated, so it can't ossify green).
#
# Scope: config defaults + workflow dart-defines only. Hardcoded host literals in
# repository/service source are intentionally NOT covered — a source-literal scan
# would collide with the legacy NIP-05 `@openvine.co` identity and content-URL
# matchers that must keep referencing openvine.co. The one source-literal call
# that did exist (the trending analytics GET in curation_repository.dart) was
# deleted as dead code in #5286, so no live backend call is left uncovered.
#
# Portable: POSIX sh constructs + grep -E only (no grep -P / rg), so it runs on
# both CI ubuntu and the macOS pre-push hook.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

APP_CONFIG="$REPO_ROOT/mobile/lib/config/app_config.dart"
WORKFLOWS_DIR="$REPO_ROOT/.github/workflows"

# Allowlist of knowingly-legacy backend hosts, tuple "surface|host".
# EMPTY after #6159 (mediaApiBaseUrl deleted, MEDIA_API_URL dart-defines dropped).
# To exempt a future legacy default, add "<config|workflow>|<host>" with a
# `# TODO(<tracking-issue>)` reason, and remove it once the host migrates.
ALLOWED=(
)

fail=0

host_of() {
  # Strip scheme, path, and port -> bare host.
  local u="${1#*://}"
  u="${u%%/*}"
  printf '%s' "${u%%:*}"
}

is_divine_host() {
  case "$1" in
    divine.video | *.divine.video) return 0 ;;
    *) return 1 ;;
  esac
}

in_allowed() {
  # $1 = "surface|host". Empty-array-safe under `set -u` (macOS bash 3.2).
  local entry
  for entry in ${ALLOWED[@]+"${ALLOWED[@]}"}; do
    [ "$entry" = "$1" ] && return 0
  done
  return 1
}

# Collect scanned "surface|host" tuples (one per line) for invariant #2.
scanned_tuples=""

check_url() {
  # $1 = surface tag, $2 = url
  local surface="$1" host
  host="$(host_of "$2")"
  scanned_tuples="$scanned_tuples
$surface|$host"
  if is_divine_host "$host"; then
    return
  fi
  if in_allowed "$surface|$host"; then
    return
  fi
  echo "❌ off-divine backend host '$host' ($surface: $2) is not on *.divine.video and not in ALLOWED."
  fail=1
}

# --- Surface A: app_config.dart *BaseUrl defaults ---------------------------
if [ ! -f "$APP_CONFIG" ]; then
  echo "❌ Missing $APP_CONFIG."
  exit 1
fi
while IFS= read -r url; do
  [ -n "$url" ] && check_url "config" "$url"
done <<EOF
$(grep -oE "defaultValue: '(https?://[^']+)'" "$APP_CONFIG" | sed -E "s/^defaultValue: '(.*)'\$/\1/")
EOF

# --- Surface B: workflow --dart-define=<KEY>URL=<url> ------------------------
if [ -d "$WORKFLOWS_DIR" ]; then
  while IFS= read -r kv; do
    [ -z "$kv" ] && continue
    check_url "workflow" "${kv#*=}"
  done <<EOF
$(grep -rhoE 'dart-define=[A-Z_]+URL=https?://[^ ]+' "$WORKFLOWS_DIR" | sort -u)
EOF
fi

# --- Invariant #2: no stale ALLOWED entries ---------------------------------
for entry in ${ALLOWED[@]+"${ALLOWED[@]}"}; do
  if ! printf '%s\n' "$scanned_tuples" | grep -qxF "$entry"; then
    echo "❌ stale ALLOWED entry '$entry' matched nothing — the ref migrated; remove it from ALLOWED."
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "Backend-host default guard failed. Backend *defaults* must be on"
  echo "*.divine.video. Fix the default, or (for a knowingly-legacy host) add a"
  echo "tracked exemption to the ALLOWED block in:"
  echo "  mobile/scripts/check_backend_host_defaults.sh"
  exit 1
fi

echo "✅ backend-host defaults are all on *.divine.video."
