#!/usr/bin/env bash
# Fails CI when a NEW lower-layer file imports the presentation layer, or when
# a NEW route-provider imports UI/router barrels. Both are the same defect: code
# below the UI reaching up into it, which drags the whole screen graph - and
# through it `providers/app_providers.dart` - into an import that had no business
# needing it (#7383, part of the #4506 provider decomposition wave).
#
# Rule 1 - lower layers must not import the presentation layer.
#   Scoped to mobile/lib/{providers,services,repositories,state}/**
#   Flags imports of package:openvine/{screens,widgets,router}/... and the
#   equivalent relative forms.
#   Exempt: package:openvine/router/route_paths.dart. It is a pure constants
#   leaf with no imports of its own, so depending on it creates no UI
#   dependency - that is the whole point of the module. Rule 3 below keeps
#   the exemption honest.
#
# Rule 2 - route providers must not import UI or the router barrel.
#   Scoped to mobile/lib/router/providers/**
#   The route parser and redirect logic operate on location strings; reaching
#   for `SomeScreen.path` or `router.dart` pulls 50+ screens into a file that
#   only needs a string/provider. Use RoutePaths and leaf provider imports.
#
# Rule 3 - route_paths.dart stays a leaf (hard invariant, no baseline).
#   It must not import anything. If it ever does, the Rule 1 exemption silently
#   stops being safe, so this fails immediately.
#
# Rules 1 and 2 are a true ratchet (compared against origin/main, not just the
# in-branch baseline). Pre-existing violators are frozen in
# scripts/baseline/layer_direction_imports.txt. See scripts/lib/list_ratchet.sh
# for NEW/STALE/GROWTH semantics.
#
# Baseline file format: one mobile-relative path per line; an optional trailing
# "# reason" documents intent. Regenerate after FIXING a file (never to add a
# new violation - that fails GROWTH):
#   UPDATE_BASELINE=1 bash mobile/scripts/check_layer_direction.sh
#
# Env overrides:
#   BASELINE_BASE_REF          git ref to compare against (default origin/main).
#   LAYER_DIRECTION_MOBILE_DIR / LAYER_DIRECTION_LIB_DIR /
#   LAYER_DIRECTION_PATH_PREFIX / LAYER_DIRECTION_BASELINE_FILE /
#   LAYER_DIRECTION_BASELINE_REPO_PATH / LAYER_DIRECTION_BASELINE_BASE_REF
#                              test seams - drive the guard against a fixture tree.
#   LAYER_DIRECTION_ALLOW_NO_BASE=1
#                              skip the growth check when the base ref cannot be
#                              loaded. Local/offline runs only - the guard
#                              otherwise FAILS CLOSED (CI must never skip it).
#
# Usage:
#   bash mobile/scripts/check_layer_direction.sh
#   (run from the repository root or from mobile/)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="${LAYER_DIRECTION_MOBILE_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
# Scan roots and baseline location are overridable so the guard can be driven
# against an isolated fixture tree by test/tools/layer_direction_test.dart.
LIB_DIR="${LAYER_DIRECTION_LIB_DIR:-$MOBILE_DIR/lib}"
PATH_PREFIX="${LAYER_DIRECTION_PATH_PREFIX:-$MOBILE_DIR}"
BASELINE_FILE="${LAYER_DIRECTION_BASELINE_FILE:-$MOBILE_DIR/scripts/baseline/layer_direction_imports.txt}"
BASELINE_REPO_PATH="${LAYER_DIRECTION_BASELINE_REPO_PATH:-mobile/scripts/baseline/layer_direction_imports.txt}"
BASE_REF="${LAYER_DIRECTION_BASELINE_BASE_REF:-${BASELINE_BASE_REF:-origin/main}}"
ALLOW_NO_BASE="${LAYER_DIRECTION_ALLOW_NO_BASE:-0}"
ALLOW_NO_BASE_VAR="LAYER_DIRECTION_ALLOW_NO_BASE"
RATCHET_LABEL="layer_direction"

LEAF_MODULE="lib/router/route_paths.dart"
LEAF_IMPORT="package:openvine/router/route_paths.dart"

# Rule 1: an import of the presentation layer, package or relative form.
UI_IMPORT_RE="^import[[:space:]]+['\"](package:openvine/(screens|widgets|router)/|(\.\./)+(screens|widgets|router)(/|\.dart['\"]))"
# Rule 2: an import that can pull route providers back up into UI code.
ROUTE_PROVIDER_UI_IMPORT_RE="^import[[:space:]]+['\"](package:openvine/(screens|widgets|features|notifications)/|package:openvine/router/router\.dart['\"]|(\.\./)+(screens|widgets|features|notifications)(/|\.dart['\"])|(\.\./)+router\.dart['\"])"

GLOBAL_EXCLUDES=(
  -not -path "*/.dart_tool/*"
  -not -path "*/build/*"
  -not -name "*.g.dart"
  -not -name "*.freezed.dart"
  -not -name "*.mocks.dart"
)

NEW_HINT="New upward imports are not allowed. Read route locations from RoutePaths, or move the provider into the layer that owns the dependency."
STALE_HINT="A file was fixed."
FOOTER="Providers, services, repositories, and state must not import screens,
widgets, or the router. Route locations come from RoutePaths
(lib/router/route_paths.dart); anything that genuinely needs to navigate
belongs in the router layer. See .claude/rules/architecture.md."

# Rule 1 violators: lower-layer files importing the UI layer, ignoring the
# sanctioned route_paths leaf.
rule1_violations() {
  find "$LIB_DIR/providers" "$LIB_DIR/services" \
       "$LIB_DIR/repositories" "$LIB_DIR/state" \
    "${GLOBAL_EXCLUDES[@]}" -name "*.dart" -print0 2>/dev/null \
    | xargs -0 grep -lE "$UI_IMPORT_RE" 2>/dev/null \
    | while IFS= read -r file; do
        # Re-check excluding the leaf import: a file whose only "UI" import is
        # route_paths.dart is compliant.
        if grep -E "$UI_IMPORT_RE" "$file" | grep -qv "$LEAF_IMPORT"; then
          printf '%s\n' "${file#"$PATH_PREFIX"/}"
        fi
      done | LC_ALL=C sort -u || true
}

# Rule 2 violators: route providers importing UI code or the router barrel.
rule2_violations() {
  find "$LIB_DIR/router/providers" \
    "${GLOBAL_EXCLUDES[@]}" -name "*.dart" -print0 2>/dev/null \
    | xargs -0 grep -lE "$ROUTE_PROVIDER_UI_IMPORT_RE" 2>/dev/null \
    | sed "s#^$PATH_PREFIX/##" | LC_ALL=C sort -u || true
}

emit_current() {
  { rule1_violations; rule2_violations; } | LC_ALL=C sort -u
}

print_baseline_header() {
  cat <<'EOF'
# Frozen baseline: files below the UI layer that import the presentation
# layer (lib/{providers,services,repositories,state} -> screens/widgets/router),
# plus route providers that import UI code or the router barrel. Generated by
# scripts/check_layer_direction.sh. The baseline may only SHRINK (growth fails
# CI vs origin/main). A trailing '# reason' marks intent.
EOF
}

# Rule 3: the sanctioned leaf must stay import-free (hard invariant).
leaf_fail=0
if [[ -f "$LIB_DIR/router/route_paths.dart" ]]; then
  if grep -qE "^import[[:space:]]+['\"]" "$LIB_DIR/router/route_paths.dart"; then
    echo "FAIL [layer_direction]: $LEAF_MODULE must not import anything:"
    grep -nE "^import[[:space:]]+['\"]" "$LIB_DIR/router/route_paths.dart" | sed 's/^/  /'
    echo "  -> Rule 1 exempts this module precisely because it is a leaf. Keep it"
    echo "     import-free, or the exemption stops being safe."
    leaf_fail=1
  fi
else
  echo "FAIL [layer_direction]: $LEAF_MODULE is missing; the Rule 1 exemption has no subject."
  leaf_fail=1
fi

# shellcheck source=lib/list_ratchet.sh
source "$SCRIPT_DIR/lib/list_ratchet.sh"

ratchet_fail=0
run_list_ratchet || ratchet_fail=$?

if [[ "$leaf_fail" -ne 0 || "$ratchet_fail" -ne 0 ]]; then
  exit 1
fi
