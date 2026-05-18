#!/usr/bin/env bash
# Fails CI if production app or package code calls raw print(), debugPrint(),
# or dart:developer log() directly instead of routing through unified_logger.
#
# Rules enforced:
#   • No bare print() calls in mobile/lib/ or mobile/packages/ source files.
#   • No debugPrint() calls in mobile/lib/ or mobile/packages/ source files.
#   • No dart:developer import (and therefore no developer.log()) in
#     mobile/lib/ or in non-SDK/non-leaf packages under mobile/packages/.
#
# Allowed exceptions (documented here — require an explicit script update):
#   • mobile/lib/scripts/migrate_logging.dart — CLI migration helper script,
#     not shipped in the app binary.
#   • mobile/packages/unified_logger/ — the logger itself uses developer.log
#     internally as its output sink.
#   • mobile/packages/nostr_sdk/ — publishable Nostr SDK; cannot depend on
#     app-internal unified_logger.
#   • mobile/packages/nostr_client/ — same rationale as nostr_sdk.
#   • mobile/packages/models/ — shared leaf data package; adding a Flutter-
#     dependent unified_logger dep would create a models ⇄ unified_logger
#     cycle. Uses developer.log directly with level: param for the one
#     error-level parse failure in pending_upload.dart.
#   • Any file under .dart_tool/, build/, or generated file patterns
#     (*.g.dart, *.freezed.dart).
#
# Usage:
#   bash mobile/scripts/check_raw_logging.sh
#   (run from the repository root or from mobile/)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

fail=0

# ---------------------------------------------------------------------------
# Exclude patterns common to all checks:
#   - .dart_tool/ and build/ directories (generated)
#   - *.g.dart, *.freezed.dart, *.mocks.dart (generated files)
#   - unified_logger package (logger internals)
#   - nostr_sdk, nostr_client, models (SDK/leaf packages without unified_logger dep)
#   - migrate_logging.dart (CLI script, not app code)
# ---------------------------------------------------------------------------

GLOBAL_EXCLUDES=(
  -not -path "*/.dart_tool/*"
  -not -path "*/build/*"
  -not -name "*.g.dart"
  -not -name "*.freezed.dart"
  -not -name "*.mocks.dart"
  -not -path "*/unified_logger/*"
  -not -path "*/nostr_sdk/*"
  -not -path "*/nostr_client/*"
  -not -path "*/packages/models/*"
  -not -name "migrate_logging.dart"
)

# ---------------------------------------------------------------------------
# 1. No bare print() in lib/ or packages/
#    Matches both leading-whitespace calls and inline calls.
#    Excludes lines that are comments (// or ///).
# ---------------------------------------------------------------------------

PRINT_VIOLATIONS=$(
  find "$MOBILE_DIR/lib" "$MOBILE_DIR/packages" \
    "${GLOBAL_EXCLUDES[@]}" \
    -name "*.dart" -print0 \
  | xargs -0 grep -lP "(?<!\/\/.*)(?<![a-zA-Z_])print\(" 2>/dev/null \
  || true
)

if [[ -n "$PRINT_VIOLATIONS" ]]; then
  echo "FAIL [avoid_print]: raw print() found in:"
  echo "$PRINT_VIOLATIONS" | sed 's/^/  /'
  fail=1
fi

# ---------------------------------------------------------------------------
# 2. No debugPrint() in lib/ or packages/
# ---------------------------------------------------------------------------

DEBUG_PRINT_VIOLATIONS=$(
  find "$MOBILE_DIR/lib" "$MOBILE_DIR/packages" \
    "${GLOBAL_EXCLUDES[@]}" \
    -name "*.dart" -print0 \
  | xargs -0 grep -l "debugPrint(" 2>/dev/null \
  || true
)

if [[ -n "$DEBUG_PRINT_VIOLATIONS" ]]; then
  echo "FAIL [avoid_debugPrint]: debugPrint() found in:"
  echo "$DEBUG_PRINT_VIOLATIONS" | sed 's/^/  /'
  fail=1
fi

# ---------------------------------------------------------------------------
# 3. No direct dart:developer import in lib/ or non-exempt packages/
# ---------------------------------------------------------------------------

DEVELOPER_LOG_VIOLATIONS=$(
  find "$MOBILE_DIR/lib" "$MOBILE_DIR/packages" \
    "${GLOBAL_EXCLUDES[@]}" \
    -name "*.dart" -print0 \
  | xargs -0 grep -l -E "^import 'dart:developer'" 2>/dev/null \
  || true
)

if [[ -n "$DEVELOPER_LOG_VIOLATIONS" ]]; then
  echo "FAIL [avoid_developer_log]: dart:developer import found in:"
  echo "$DEVELOPER_LOG_VIOLATIONS" | sed 's/^/  /'
  fail=1
fi

# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------

if [[ "$fail" -eq 0 ]]; then
  echo "OK: No raw logging violations found."
else
  echo ""
  echo "Raw logging must go through unified_logger (Log.debug/info/warning/error)."
  echo "See mobile/packages/unified_logger/lib/src/unified_logger.dart for the API."
  exit 1
fi
