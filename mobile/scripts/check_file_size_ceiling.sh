#!/usr/bin/env bash
# File-size advisory (epic #4339): reports every Dart file under mobile/lib
# whose length exceeds FILE_SIZE_THRESHOLD (default 800) lines and is either
# NEW (absent from scripts/baseline/file_sizes.txt) or has GROWN past its
# recorded ceiling there.
#
# This is ADVISORY: it prints warnings and ALWAYS exits 0 — it never fails CI.
# The 800-line ceiling was downgraded from a hard gate to a warning (team
# decision) so a small edit to an already-large file no longer forces an
# unrelated refactor in the same PR. The baseline scopes the warning to files
# you newly add or grow, rather than nagging on every pre-existing large file.
#
# Excludes generated code by PATH (mobile/lib/l10n/generated/) and by suffix
# (*.g.dart/*.freezed.dart/*.gr.dart/*.config.dart/*.mocks.dart). The l10n
# generated files lack codegen suffixes, so the PATH exclusion is required —
# without it the count is inflated by ~19 files.
#
# Refresh the baseline (after intentionally adding/growing a file to silence
# its warning, or after shrinking one):
#   UPDATE_BASELINE=1 bash mobile/scripts/check_file_size_ceiling.sh
# Run (from repo root or mobile/): bash mobile/scripts/check_file_size_ceiling.sh
#
# Bash 3.2 compatible (no associative arrays) for local macOS runs — set
# comparisons use sort/join with LC_ALL=C.

set -euo pipefail

# Byte-wise, locale-independent ordering so sort/join agree across macOS (local)
# and Linux (CI); otherwise the baseline diff can falsely flag NEW/GROWTH.
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TAB="$(printf '\t')"

RATCHET_LABEL="file_size_ceiling"
THRESHOLD="${FILE_SIZE_THRESHOLD:-800}"
SCAN_DIR="${FILE_SIZE_SCAN_DIR:-$MOBILE_DIR/lib}"
PATH_PREFIX="${FILE_SIZE_PATH_PREFIX:-$MOBILE_DIR}"
BASELINE_FILE="${FILE_SIZE_BASELINE_FILE:-$SCRIPT_DIR/baseline/file_sizes.txt}"

HINT="The ${THRESHOLD}-line ceiling is advisory — this does NOT block CI. Prefer
extracting widget/class/service concerns into focused files over growing a large
file, but a small edit need not trigger a refactor. Refresh the baseline to
silence an intentional addition: UPDATE_BASELINE=1 bash mobile/scripts/check_${RATCHET_LABEL}.sh"

# Print "relpath<TAB>loc" for every oversized non-generated Dart file, sorted by
# path (field 1) so join behaves deterministically.
emit_current() {
  find "$SCAN_DIR" \
    -type f -name '*.dart' \
    -not -path '*/l10n/generated/*' \
    -not -path '*/.dart_tool/*' \
    -not -path '*/build/*' \
    ! -name '*.g.dart' ! -name '*.freezed.dart' ! -name '*.gr.dart' \
    ! -name '*.config.dart' ! -name '*.mocks.dart' \
    -print0 2>/dev/null \
  | while IFS= read -r -d '' f; do
      loc="$(wc -l < "$f" | tr -d '[:space:]')"
      if [[ "${loc:-0}" -gt "$THRESHOLD" ]]; then
        printf '%s\t%s\n' "${f#"$PATH_PREFIX"/}" "$loc"
      fi
    done \
  | LC_ALL=C sort -t "$TAB" -k1,1
}

print_baseline_header() {
  cat <<EOF
# Advisory baseline: Dart files under mobile/lib over ${THRESHOLD} lines, each
# with its current line count as a CEILING (format: relpath<TAB>loc). Generated
# by scripts/check_file_size_ceiling.sh. A NEW oversized file or one that grows
# past its ceiling is reported as a WARNING — advisory, never fails CI. Epic: #4339.
# Regenerate: UPDATE_BASELINE=1 bash scripts/check_file_size_ceiling.sh
EOF
}

# Strip "# reason" trailing comments, comment lines, and blanks; sort by path.
strip_baseline() {
  sed 's/[[:space:]]*#.*//' | grep -v '^[[:space:]]*$' | LC_ALL=C sort -t "$TAB" -k1,1 || true
}

CURRENT="$(emit_current)"

if [[ "${UPDATE_BASELINE:-0}" == "1" ]]; then
  mkdir -p "$(dirname "$BASELINE_FILE")"
  { print_baseline_header; printf '%s\n' "$CURRENT" | grep -v '^[[:space:]]*$' || true; } > "$BASELINE_FILE"
  count="$(printf '%s\n' "$CURRENT" | grep -c . || true)"
  echo "OK [$RATCHET_LABEL]: wrote $count baseline entries to ${BASELINE_FILE#"$MOBILE_DIR"/}."
  exit 0
fi

CUR_F="$(mktemp)"; BASE_F="$(mktemp)"
trap 'rm -f "$CUR_F" "$BASE_F"' EXIT

printf '%s\n' "$CURRENT" | grep -v '^[[:space:]]*$' > "$CUR_F" || true
if [[ -f "$BASELINE_FILE" ]]; then
  strip_baseline < "$BASELINE_FILE" > "$BASE_F"
else
  : > "$BASE_F"
fi

warn=0

# NEW: oversized file present now but absent from the baseline.
new="$(join -t "$TAB" -v1 "$CUR_F" "$BASE_F" || true)"
if [[ -n "$new" ]]; then
  echo "WARN [$RATCHET_LABEL]: NEW file(s) over ${THRESHOLD} lines, not in the baseline:"
  echo "$new" | sed 's/^/  /'
  warn=1
fi

# GROWTH: baselined file now exceeds its recorded ceiling.
grown="$(join -t "$TAB" "$CUR_F" "$BASE_F" | awk -F "$TAB" '$2 > $3 { printf "%s\t%s -> %s\n", $1, $3, $2 }' || true)"
if [[ -n "$grown" ]]; then
  echo "WARN [$RATCHET_LABEL]: file(s) GREW past their recorded ceiling (was -> now):"
  echo "$grown" | sed 's/^/  /'
  warn=1
fi

if [[ "$warn" -eq 0 ]]; then
  count="$(grep -c . "$CUR_F" || true)"
  echo "OK [$RATCHET_LABEL]: $count file(s) over ${THRESHOLD} lines, none new or grown."
  exit 0
fi

echo ""
echo "$HINT"
# Advisory: surface the findings above but never fail CI.
exit 0
