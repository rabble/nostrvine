#!/usr/bin/env bash
# Fails CI when a NEW lower-layer file imports the presentation layer, or when
# a NEW route-provider imports a screen. Both are the same defect: code below
# the UI reaching up into it, which drags the whole screen graph — and through
# it `providers/app_providers.dart` — into an import that had no business
# needing it (#7383, part of the #4506 provider decomposition wave).
#
# Rule 1 — lower layers must not import the presentation layer.
#   Scoped to mobile/lib/{providers,services,repositories,state}/**
#   Flags imports of package:openvine/{screens,widgets,router}/… (and the
#   equivalent relative forms).
#   Exempt: package:openvine/router/route_paths.dart. It is a pure constants
#   leaf with no imports of its own, so depending on it creates no UI
#   dependency — that is the whole point of the module. Rule 3 below keeps
#   the exemption honest.
#
# Rule 2 — route providers must not import screens.
#   Scoped to mobile/lib/router/providers/**
#   The route parser and redirect logic operate on location strings; reaching
#   for `SomeScreen.path` pulls 50+ screens into a file that only needs the
#   string. Use RoutePaths instead.
#
# Rule 3 — route_paths.dart stays a leaf (hard invariant, no baseline).
#   It must not import any package:openvine/… library. If it ever does, the
#   Rule 1 exemption silently stops being safe, so this fails immediately.
#
# Rules 1 and 2 are a true ratchet (compared against origin/main, not just the
# in-branch baseline). Pre-existing violators are frozen in
# scripts/baseline/layer_direction_imports.txt. The guard fails on:
#   • NEW    — a current violation not declared in the (in-branch) baseline.
#   • STALE  — a baselined file that no longer violates (fixed; the baseline
#              must shrink to lock the win in).
#   • GROWTH — the in-branch baseline contains entries not present in the
#              baseline on the base ref (default origin/main), which would let
#              a PR add a violation and regenerate its way out of the failure.
# On the commit that first introduces the baseline (absent on the base ref),
# the GROWTH check is skipped (bootstrap).
#
# Baseline file format: one mobile-relative path per line; an optional trailing
# "# reason" documents intent. Regenerate after FIXING a file (never to add a
# new violation — that fails GROWTH):
#   UPDATE_BASELINE=1 bash mobile/scripts/check_layer_direction.sh
#
# Env overrides:
#   BASELINE_BASE_REF          git ref to compare against (default origin/main).
#   LAYER_DIRECTION_LIB_DIR / LAYER_DIRECTION_PATH_PREFIX / LAYER_DIRECTION_BASELINE_FILE
#   LAYER_DIRECTION_BASELINE_BASE_REF
#                              test seams — drive the guard against a fixture tree.
#   LAYER_DIRECTION_ALLOW_NO_BASE=1
#                              skip the growth check when the base ref cannot be
#                              loaded. Local/offline runs only — the guard
#                              otherwise FAILS CLOSED (CI must never skip it).
#
# Usage:
#   bash mobile/scripts/check_layer_direction.sh
#   (run from the repository root or from mobile/)

set -euo pipefail

# Byte-wise, locale-independent ordering so sort/comm agree across macOS (local)
# and Linux (CI); otherwise the baseline diff can falsely flag NEW/STALE/GROWTH.
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$MOBILE_DIR/.." && pwd)"
# Scan roots and baseline location are overridable so the guard can be driven
# against an isolated fixture tree by test/tools/layer_direction_test.dart.
LIB_DIR="${LAYER_DIRECTION_LIB_DIR:-$MOBILE_DIR/lib}"
PATH_PREFIX="${LAYER_DIRECTION_PATH_PREFIX:-$MOBILE_DIR}"
BASELINE_FILE="${LAYER_DIRECTION_BASELINE_FILE:-$SCRIPT_DIR/baseline/layer_direction_imports.txt}"
BASELINE_REPO_PATH="mobile/scripts/baseline/layer_direction_imports.txt"
BASE_REF="${LAYER_DIRECTION_BASELINE_BASE_REF:-${BASELINE_BASE_REF:-origin/main}}"

LEAF_MODULE="lib/router/route_paths.dart"
LEAF_IMPORT="package:openvine/router/route_paths.dart"

# Rule 1: an import of the presentation layer, package or relative form.
UI_IMPORT_RE="^import[[:space:]]+['\"](package:openvine/(screens|widgets|router)/|(\.\./)+(screens|widgets|router)/)"
# Rule 2: an import of a screen (or co-located feature/notification view).
SCREEN_IMPORT_RE="^import[[:space:]]+['\"](package:openvine/(screens|widgets|features|notifications)/|(\.\./)+(screens|widgets|features|notifications)/)"

GLOBAL_EXCLUDES=(
  -not -path "*/.dart_tool/*"
  -not -path "*/build/*"
  -not -name "*.g.dart"
  -not -name "*.freezed.dart"
  -not -name "*.mocks.dart"
)

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

# Rule 2 violators: route providers importing screens.
rule2_violations() {
  find "$LIB_DIR/router/providers" \
    "${GLOBAL_EXCLUDES[@]}" -name "*.dart" -print0 2>/dev/null \
    | xargs -0 grep -lE "$SCREEN_IMPORT_RE" 2>/dev/null \
    | sed "s#^$PATH_PREFIX/##" | LC_ALL=C sort -u || true
}

current_violations() {
  { rule1_violations; rule2_violations; } | LC_ALL=C sort -u
}

strip_baseline() {
  sed 's/[[:space:]]*#.*//; s/[[:space:]]*$//' | grep -v '^$' | LC_ALL=C sort || true
}

baseline_paths() {
  [[ -f "$BASELINE_FILE" ]] && strip_baseline < "$BASELINE_FILE" || true
}

baseline_header() {
  cat <<'EOF'
# Frozen baseline: files below the UI layer that import the presentation
# layer (lib/{providers,services,repositories,state} -> screens/widgets/router),
# plus route providers that import screens. Generated by
# scripts/check_layer_direction.sh. The baseline may only SHRINK (growth fails
# CI vs origin/main). A trailing '# reason' marks intent.
EOF
}

write_baseline() {
  local reasons_file
  reasons_file="$(mktemp)"

  if [[ -f "$BASELINE_FILE" ]]; then
    awk '
      /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
      {
        path = $0
        comment = ""
        if (match(path, /[[:space:]]+#.*/)) {
          comment = substr(path, RSTART)
          path = substr(path, 1, RSTART - 1)
          sub(/[[:space:]]+$/, "", path)
        }
        if (comment != "") {
          print path "\t" comment
        }
      }
    ' "$BASELINE_FILE" > "$reasons_file"
  fi

  {
    baseline_header
    while IFS= read -r path; do
      [[ -z "$path" ]] && continue
      reason="$(awk -F '\t' -v target="$path" '$1 == target { print $2; exit }' "$reasons_file")"
      if [[ -n "$reason" ]]; then
        printf '%s %s\n' "$path" "$reason"
      else
        printf '%s\n' "$path"
      fi
    done <<< "$CURRENT"
  } > "$BASELINE_FILE"

  rm -f "$reasons_file"
}

CURRENT="$(current_violations)"

if [[ "${UPDATE_BASELINE:-0}" == "1" ]]; then
  mkdir -p "$(dirname "$BASELINE_FILE")"
  write_baseline
  count="$(printf '%s\n' "$CURRENT" | grep -c . || true)"
  echo "OK: wrote $count baseline entries to ${BASELINE_FILE#"$MOBILE_DIR"/}."
  exit 0
fi

BASELINE="$(baseline_paths)"

MAIN_BASELINE=""
load_base_baseline() {
  if ! git -C "$REPO_ROOT" rev-parse --verify --quiet "$BASE_REF" >/dev/null 2>&1; then
    git -C "$REPO_ROOT" fetch --quiet --depth=1 origin main 2>/dev/null || true
  fi
  if ! git -C "$REPO_ROOT" rev-parse --verify --quiet "$BASE_REF" >/dev/null 2>&1; then
    return 1
  fi
  if ! git -C "$REPO_ROOT" cat-file -e "$BASE_REF:$BASELINE_REPO_PATH" 2>/dev/null; then
    return 2
  fi
  local raw
  if ! raw="$(git -C "$REPO_ROOT" show "$BASE_REF:$BASELINE_REPO_PATH" 2>/dev/null)"; then
    return 3
  fi
  MAIN_BASELINE="$(printf '%s\n' "$raw" | strip_baseline)"
  return 0
}

fail=0

# Rule 3: the sanctioned leaf must stay import-free (hard invariant).
if [[ -f "$LIB_DIR/router/route_paths.dart" ]]; then
  if grep -qE "^import[[:space:]]+['\"]package:openvine/" "$LIB_DIR/router/route_paths.dart"; then
    echo "FAIL [layer_direction]: $LEAF_MODULE must not import package:openvine/…:"
    grep -nE "^import[[:space:]]+['\"]package:openvine/" "$LIB_DIR/router/route_paths.dart" | sed 's/^/  /'
    echo "  -> Rule 1 exempts this module precisely because it is a leaf. Keep it"
    echo "     free of openvine imports, or the exemption stops being safe."
    fail=1
  fi
else
  echo "FAIL [layer_direction]: $LEAF_MODULE is missing; the Rule 1 exemption has no subject."
  fail=1
fi

NEW="$(comm -13 <(printf '%s\n' "$BASELINE") <(printf '%s\n' "$CURRENT") | grep -v '^$' || true)"
if [[ -n "$NEW" ]]; then
  echo "FAIL [layer_direction]: NEW upward import(s) from below the UI layer:"
  echo "$NEW" | sed 's/^/  /'
  fail=1
fi

STALE="$(comm -23 <(printf '%s\n' "$BASELINE") <(printf '%s\n' "$CURRENT") | grep -v '^$' || true)"
if [[ -n "$STALE" ]]; then
  echo "FAIL [layer_direction]: baseline entries that no longer import upward:"
  echo "$STALE" | sed 's/^/  /'
  echo "  -> A file was fixed. Lock the win by shrinking the baseline:"
  echo "     UPDATE_BASELINE=1 bash mobile/scripts/check_layer_direction.sh"
  fail=1
fi

set +e
load_base_baseline
base_status=$?
set -e
case "$base_status" in
  0)
    GROWTH="$(comm -23 <(printf '%s\n' "$BASELINE") <(printf '%s\n' "$MAIN_BASELINE") | grep -v '^$' || true)"
    if [[ -n "$GROWTH" ]]; then
      echo "FAIL [layer_direction]: baseline GREW vs ${BASE_REF} (the ratchet may only shrink):"
      echo "$GROWTH" | sed 's/^/  /'
      echo "  -> New upward imports are not allowed. Read the location from"
      echo "     RoutePaths, or move the provider into the layer that owns the"
      echo "     dependency, instead of adding it to the baseline."
      fail=1
    fi
    ;;
  2)
    echo "NOTE [layer_direction]: no baseline on ${BASE_REF} yet (introducing the guard); skipping growth check."
    ;;
  *)
    if [[ "${LAYER_DIRECTION_ALLOW_NO_BASE:-0}" == "1" ]]; then
      echo "NOTE [layer_direction]: ${BASE_REF} unavailable; skipping growth check (LAYER_DIRECTION_ALLOW_NO_BASE=1, local opt-out)."
    else
      echo "FAIL [layer_direction]: could not load the baseline from ${BASE_REF}, so the"
      echo "  growth ratchet cannot be verified — failing closed. Ensure ${BASE_REF} is"
      echo "  fetched (CI runs 'git fetch --depth=1 origin main' before this guard)."
      echo "  For a local run without a base ref, set LAYER_DIRECTION_ALLOW_NO_BASE=1."
      fail=1
    fi
    ;;
esac

if [[ "$fail" -eq 0 ]]; then
  echo "OK: No new upward layer imports (baseline frozen, ratcheted vs ${BASE_REF})."
else
  echo ""
  echo "Providers, services, repositories, and state must not import screens,"
  echo "widgets, or the router. Route locations come from RoutePaths"
  echo "(lib/router/route_paths.dart); anything that genuinely needs to navigate"
  echo "belongs in the router layer. See .claude/rules/architecture.md."
  exit 1
fi
