#!/usr/bin/env bash
# Fails CI if a new @riverpod annotation or StateProvider appears outside
# the allowed provider directories.
#
# Rules enforced:
#   • No @riverpod / @Riverpod( annotations in mobile/lib/ outside
#     the allowed provider directories.
#   • No StateProvider( calls in mobile/lib/ outside the allowed provider
#     directories.
#
# Background:
#   Divine is mid-migration from Riverpod to BLoC/Cubit for UI state.
#   The full ownership boundary is documented in docs/BLOC_UI_MIGRATION_PRD.md.
#   This guard enforces the two highest-signal extension points for new
#   Riverpod UI state: @riverpod annotations and StateProvider declarations.
#
# Allowed locations for @riverpod annotations (must be documented here if added):
#   • mobile/lib/providers/ — primary home for app-wide DI providers.
#   • mobile/lib/*/providers/ — feature-local provider directories (e.g.
#     lib/features/feature_flags/providers/). Must contain only DI/service
#     providers, never UI state.
#   • mobile/lib/services/ — service classes that self-register as providers
#     (e.g. OpenvineMediaCache). Must be infrastructure, not UI state.
#   • *.g.dart, *.freezed.dart, *.mocks.dart — generated files (may contain
#     provider references in generated glue code).
#   • .dart_tool/ and build/ — build artifacts, never app code.
#
# Usage:
#   bash mobile/scripts/check_riverpod_boundary.sh
#   (run from the repository root or from mobile/)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

fail=0

GLOBAL_EXCLUDES=(
  -not -path "*/.dart_tool/*"
  -not -path "*/build/*"
  -not -name "*.g.dart"
  -not -name "*.freezed.dart"
  -not -name "*.mocks.dart"
  -not -path "*/lib/providers/*"
  -not -path "*/lib/services/*"
  -not -path "*/providers/*"
)

# ---------------------------------------------------------------------------
# 1. No @riverpod annotation outside allowed provider directories
#    Catches both the shorthand @riverpod and the parameterised @Riverpod(...)
#    forms produced by riverpod_annotation / riverpod_generator.
# ---------------------------------------------------------------------------

RIVERPOD_ANNOTATION_VIOLATIONS=$(
  find "$MOBILE_DIR/lib" \
    "${GLOBAL_EXCLUDES[@]}" \
    -name "*.dart" -print0 \
  | xargs -0 grep -l -E "@riverpod|@Riverpod\(" 2>/dev/null \
  || true
)

if [[ -n "$RIVERPOD_ANNOTATION_VIOLATIONS" ]]; then
  echo "FAIL [riverpod_boundary]: @riverpod annotation found outside allowed provider directories in:"
  echo "$RIVERPOD_ANNOTATION_VIOLATIONS" | sed 's/^/  /'
  fail=1
fi

# ---------------------------------------------------------------------------
# 2. No StateProvider( outside allowed provider directories
#    StateProvider is the legacy Riverpod UI-state pattern explicitly listed
#    as disallowed for new code in docs/BLOC_UI_MIGRATION_PRD.md.
# ---------------------------------------------------------------------------

STATE_PROVIDER_VIOLATIONS=$(
  find "$MOBILE_DIR/lib" \
    "${GLOBAL_EXCLUDES[@]}" \
    -name "*.dart" -print0 \
  | xargs -0 grep -l "StateProvider(" 2>/dev/null \
  || true
)

if [[ -n "$STATE_PROVIDER_VIOLATIONS" ]]; then
  echo "FAIL [riverpod_boundary]: StateProvider( found outside allowed provider directories in:"
  echo "$STATE_PROVIDER_VIOLATIONS" | sed 's/^/  /'
  fail=1
fi

# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------

if [[ "$fail" -eq 0 ]]; then
  echo "OK: No Riverpod boundary violations found."
else
  echo ""
  echo "New @riverpod annotations and StateProvider declarations must live in"
  echo "mobile/lib/providers/, mobile/lib/*/providers/, or mobile/lib/services/."
  echo "For new UI state, use BLoC/Cubit instead of @riverpod or StateProvider."
  echo "See docs/BLOC_UI_MIGRATION_PRD.md — 'Allowed / Disallowed Patterns'."
  exit 1
fi
