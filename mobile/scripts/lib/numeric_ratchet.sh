#!/usr/bin/env bash
# Shared "per-key numeric ceiling" ratchet engine, the numeric sibling of
# lib/list_ratchet.sh. Where list_ratchet freezes a SET membership (an item is in
# or out), this freezes a NUMBER per key: each baseline line is `key<TAB>count`
# and a key's count may only ever DECREASE.
#
# Fails (vs the in-branch baseline AND the base ref):
#   • NEW    — a key present now but absent from the baseline.
#   • GROWTH — a baselined key whose current count exceeds its frozen ceiling.
#   • STALE  — a baselined key no longer emitted (removed/renamed/dropped below a
#              detector threshold); the baseline must shrink to lock the win.
#   • BYPASS — the in-branch baseline ADDS a key or RAISES a ceiling vs the base
#              ref (closes the "grow then rerun UPDATE_BASELINE" loophole).
#   On the commit that first introduces the baseline (absent on the base ref),
#   the bypass check is skipped (bootstrap). If the base baseline cannot be
#   loaded, the guard FAILS CLOSED unless ALLOW_NO_BASE=1 (local opt-out).
#
# A key may DECREASE freely without churning the baseline (low friction); only
# growth/new/removal fails. Decreases can optionally be locked in via
# UPDATE_BASELINE to tighten the ceiling.
#
# The sourcing script MUST define, before calling run_numeric_ratchet:
#   RATCHET_LABEL        short id used in messages
#   MOBILE_DIR           absolute path to the mobile/ dir (REPO_ROOT derived)
#   BASELINE_FILE        absolute path to the baseline file
#   BASELINE_REPO_PATH   repo-relative path (for `git show <ref>:<path>`)
#   BASE_REF             git ref to ratchet against (e.g. origin/main)
#   ALLOW_NO_BASE        "1" to soft-skip the bypass check when base is unloadable
#   ALLOW_NO_BASE_VAR    name of the env var that sets ALLOW_NO_BASE (for hints)
#   NEW_HINT             guidance printed under a NEW/GROWTH/BYPASS failure
#   STALE_HINT           guidance printed under a STALE failure
#   FOOTER               closing guidance printed on any failure
#   emit_current()       prints the current "key<TAB>count" lines (one per key)
#   print_baseline_header()  prints the baseline file header comment block
#
# Honours UPDATE_BASELINE=1 to regenerate. Bash 3.2 compatible (sort/join only).

set -euo pipefail
export LC_ALL=C

_nr_tab() { printf '\t'; }

# Strip "# reason" trailing comments, comment lines, blanks; sort by key (field 1).
_nr_strip() {
  sed 's/[[:space:]]*#.*//' | grep -v '^[[:space:]]*$' | LC_ALL=C sort -t "$(_nr_tab)" -k1,1 || true
}

run_numeric_ratchet() {
  local TAB; TAB="$(_nr_tab)"
  local REPO_ROOT; REPO_ROOT="$(cd "$MOBILE_DIR/.." && pwd)"
  local CURRENT; CURRENT="$(emit_current)"

  if [[ "${UPDATE_BASELINE:-0}" == "1" ]]; then
    mkdir -p "$(dirname "$BASELINE_FILE")"
    { print_baseline_header; printf '%s\n' "$CURRENT" | grep -v '^[[:space:]]*$' || true; } > "$BASELINE_FILE"
    local count; count="$(printf '%s\n' "$CURRENT" | grep -c . || true)"
    echo "OK [$RATCHET_LABEL]: wrote $count baseline entries to ${BASELINE_FILE#"$MOBILE_DIR"/}."
    return 0
  fi

  local CUR_F BASE_F MAIN_F
  CUR_F="$(mktemp)"; BASE_F="$(mktemp)"; MAIN_F="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '$CUR_F' '$BASE_F' '$MAIN_F'" RETURN

  printf '%s\n' "$CURRENT" | grep -v '^[[:space:]]*$' | LC_ALL=C sort -t "$TAB" -k1,1 > "$CUR_F" || true
  if [[ -f "$BASELINE_FILE" ]]; then _nr_strip < "$BASELINE_FILE" > "$BASE_F"; else : > "$BASE_F"; fi

  local fail=0 new grown stale
  new="$(join -t "$TAB" -v1 "$CUR_F" "$BASE_F" || true)"
  if [[ -n "$new" ]]; then
    echo "FAIL [$RATCHET_LABEL]: NEW key(s) not in the baseline:"
    echo "$new" | sed 's/^/  /'
    echo "  -> $NEW_HINT"
    fail=1
  fi
  grown="$(join -t "$TAB" "$CUR_F" "$BASE_F" | awk -F "$TAB" '$2 > $3 { printf "%s\t%s -> %s\n", $1, $3, $2 }' || true)"
  if [[ -n "$grown" ]]; then
    echo "FAIL [$RATCHET_LABEL]: count(s) GREW past the frozen ceiling (was -> now):"
    echo "$grown" | sed 's/^/  /'
    echo "  -> $NEW_HINT"
    fail=1
  fi
  stale="$(join -t "$TAB" -v2 "$CUR_F" "$BASE_F" || true)"
  if [[ -n "$stale" ]]; then
    echo "FAIL [$RATCHET_LABEL]: baselined key(s) no longer emitted:"
    echo "$stale" | sed 's/^/  /'
    echo "  -> $STALE_HINT Lock the win by regenerating the baseline:"
    echo "     UPDATE_BASELINE=1 bash mobile/scripts/check_${RATCHET_LABEL}.sh"
    fail=1
  fi

  local base_status=0
  if ! git -C "$REPO_ROOT" rev-parse --verify --quiet "$BASE_REF" >/dev/null 2>&1; then
    git -C "$REPO_ROOT" fetch --quiet --depth=1 origin main 2>/dev/null || true
  fi
  if ! git -C "$REPO_ROOT" rev-parse --verify --quiet "$BASE_REF" >/dev/null 2>&1; then
    base_status=1
  elif ! git -C "$REPO_ROOT" cat-file -e "$BASE_REF:$BASELINE_REPO_PATH" 2>/dev/null; then
    base_status=2
  elif ! git -C "$REPO_ROOT" show "$BASE_REF:$BASELINE_REPO_PATH" 2>/dev/null | _nr_strip > "$MAIN_F"; then
    base_status=3
  fi
  case "$base_status" in
    0)
      local added raised
      added="$(join -t "$TAB" -v1 "$BASE_F" "$MAIN_F" || true)"
      raised="$(join -t "$TAB" "$BASE_F" "$MAIN_F" | awk -F "$TAB" '$2 > $3 { printf "%s\t%s -> %s\n", $1, $3, $2 }' || true)"
      if [[ -n "$added" || -n "$raised" ]]; then
        echo "FAIL [$RATCHET_LABEL]: baseline ADDED a key or RAISED a ceiling vs ${BASE_REF} (may only shrink):"
        [[ -n "$added" ]] && echo "$added" | sed 's/^/  +added /'
        [[ -n "$raised" ]] && echo "$raised" | sed 's/^/  ^raised /'
        echo "  -> $NEW_HINT"
        fail=1
      fi
      ;;
    2)
      echo "NOTE [$RATCHET_LABEL]: no baseline on ${BASE_REF} yet (introducing the guard); skipping growth-vs-base check."
      ;;
    *)
      if [[ "$ALLOW_NO_BASE" == "1" ]]; then
        echo "NOTE [$RATCHET_LABEL]: ${BASE_REF} unavailable; skipping growth-vs-base check (${ALLOW_NO_BASE_VAR}=1, local opt-out)."
      else
        echo "FAIL [$RATCHET_LABEL]: could not load the baseline from ${BASE_REF}, so the"
        echo "  growth-vs-base ratchet cannot be verified — failing closed. Ensure ${BASE_REF}"
        echo "  is fetched (CI runs 'git fetch --depth=1 origin main' before this guard)."
        echo "  For a local run without a base ref, set ${ALLOW_NO_BASE_VAR}=1 to skip."
        fail=1
      fi
      ;;
  esac

  if [[ "$fail" -eq 0 ]]; then
    local count; count="$(grep -c . "$CUR_F" || true)"
    echo "OK [$RATCHET_LABEL]: $count key(s) tracked, none grew (frozen, ratcheted vs ${BASE_REF})."
    return 0
  fi
  echo ""
  echo "$FOOTER"
  return 1
}
