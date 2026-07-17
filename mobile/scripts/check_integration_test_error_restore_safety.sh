#!/usr/bin/env bash
# Fails CI if an integration_test suite restores ErrorWidget.builder or
# FlutterError.onError in an exception-UNSAFE way (#5839).
#
# The integration_test files (mobile/integration_test) override ErrorWidget.builder
# and FlutterError.onError per test and must restore them so an early `expect`
# failure cannot leak the override into a later test in the same file. The
# correct, exception-safe shape uses the test_setup helpers plus addTearDown:
#
#   final originalOnError = suppressSetStateErrors();
#   addTearDown(() => restoreErrorHandler(originalOnError));      // onError: teardown-only
#   final originalErrorBuilder = saveErrorWidgetBuilder();
#   addTearDown(() => restoreErrorWidgetBuilder(originalErrorBuilder));  // builder: suspenders
#   ...
#   restoreErrorWidgetBuilder(originalErrorBuilder);             // builder: inline belt
#
# ErrorWidget.builder MUST also be restored inline: flutter_test's
# _verifyErrorWidgetBuilderUnset runs at end-of-body BEFORE addTearDown, so an
# addTearDown-only builder restore fails the happy path. See
# test/integration_test_error_restore_contract_test.dart for the pinned contract.
#
# Policy (presence-based, scoped to mobile/integration_test):
#   Rule 1 — no raw `ErrorWidget.builder =` / `FlutterError.onError =`
#            assignments outside helpers/ (use the test_setup helpers instead).
#   Rule 2 — a file that calls saveErrorWidgetBuilder() must contain an
#            addTearDown restoring the builder; a file that calls
#            suppressSetStateErrors() must contain an addTearDown restoring
#            onError. (This catches a save/suppress with no exception-safe
#            teardown. The inline builder belt is required by the framework and
#            enforced by the contract test above, not by this script.)
#
# Allowlist: integration_test/helpers/** (defines the raw ops the helpers wrap).
# The non-patrol contract test lives under mobile/test/ and is out of scope here.
#
# Usage:
#   bash mobile/scripts/check_integration_test_error_restore_safety.sh
#   (run from the repository root or from mobile/)
set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
IT_DIR="$MOBILE_DIR/integration_test"

if [[ ! -d "$IT_DIR" ]]; then
  echo "check_integration_test_error_restore_safety: no integration_test dir; skipping."
  exit 0
fi

fail=0

# All .dart under integration_test except the helpers/ allowlist. Word-splitting
# is safe: integration_test paths contain no spaces (matches the convention in
# the sibling check_*.sh guards, and keeps this portable to macOS bash 3.2).
files=$(find "$IT_DIR" -name '*.dart' -not -path "$IT_DIR/helpers/*" | sort)

for f in $files; do
  rel="${f#"$MOBILE_DIR"/}"

  # Rule 1: raw assignments (single '=', not '==') are banned outside helpers/.
  if grep -nE '(ErrorWidget\.builder|FlutterError\.onError)[[:space:]]*=([^=]|$)' "$f" \
    >/dev/null 2>&1; then
    echo "✗ $rel: raw ErrorWidget.builder / FlutterError.onError assignment."
    grep -nE '(ErrorWidget\.builder|FlutterError\.onError)[[:space:]]*=([^=]|$)' "$f" \
      | sed 's/^/    /'
    echo "    → use saveErrorWidgetBuilder()/restoreErrorWidgetBuilder()/"
    echo "      suppressSetStateErrors()/restoreErrorHandler() from helpers/test_setup.dart."
    fail=1
  fi

  # Rule 2a: saveErrorWidgetBuilder() requires an addTearDown restoring it.
  if grep -q 'saveErrorWidgetBuilder(' "$f" \
    && ! grep -Eq 'addTearDown\(.*restoreErrorWidgetBuilder' "$f"; then
    echo "✗ $rel: calls saveErrorWidgetBuilder() but has no"
    echo "    addTearDown(() => restoreErrorWidgetBuilder(...)) — restore leaks on a throw."
    fail=1
  fi

  # Rule 2b: suppressSetStateErrors() requires an addTearDown restoring onError.
  if grep -q 'suppressSetStateErrors(' "$f" \
    && ! grep -Eq 'addTearDown\(.*restoreErrorHandler' "$f"; then
    echo "✗ $rel: calls suppressSetStateErrors() but has no"
    echo "    addTearDown(() => restoreErrorHandler(...)) — restore leaks on a throw."
    fail=1
  fi
done

if [[ "$fail" -ne 0 ]]; then
  echo ""
  echo "Exception-unsafe error-handler restore(s) in integration_test (#5839)."
  echo "See test/integration_test_error_restore_contract_test.dart for the pattern."
  exit 1
fi

echo "✓ integration_test error-handler restores are exception-safe."
