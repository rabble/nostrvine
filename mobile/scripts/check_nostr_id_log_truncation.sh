#!/usr/bin/env bash
# Nostr diagnostic-log ratchet (#3372): shortened public identifiers and any
# secret value reaching a log/debug sink are frozen at zero per file in
# scripts/baseline/nostr_id_log_truncation.txt — a CEILING that may only shrink.
# The baseline is intentionally EMPTY: #3372 closed all 19 sites, so any entry
# here is a regression.
#
# Why: AGENTS.md → "Never truncate Nostr IDs in code, logs, tests, analytics, or
# debug output. Use full values and let UI layout handle overflow visually."
# A truncated identifier is worse than no identifier — it looks correlatable and
# is not. `npub1abc...wxyz` cannot be grepped against relay logs, matched to a
# funnelcake row, or pasted into a support ticket, and 8 hex characters of an
# event id is 32 bits, which collides in a store this size. Every site closed by
# #3372 had the full value in hand one expression earlier.
#
# What this guard distinguishes:
#   • UI shortening stays allowed — NostrKeyUtils.truncateNpub and friends have
#     a display sink, not a log sink, and this detector ignores them.
#   • SECRETS are a separate zero-tolerance rule. An nsec is not a Nostr ID to
#     preserve; it is a credential to omit. Whole and shortened values both fail.
#     The redaction layers are BugReportConfig.sensitivePatterns (nsec1 /
#     ncryptsec1) and sanitizeForCrashReport (npub1 / nsec1 / email). Both
#     deliberately keep public event ids and pubkeys intact.
#
# Detector: scripts/lib/nostr_id_log_truncation_detector.dart (a real Dart AST).
# A grep cannot do this: the signal is a PATH from a shortening expression to a
# log call, often through a local (`final preview = id.substring(0, 8)`) or a
# one-frame helper (`_maskKey(npub)`), and `...` in a log line is overwhelmingly
# prose ("Publishing Nostr event..."). See that file's header for the rule and
# its stated limits.
#
# Regenerate ONLY after an intentional, reviewed change:
#   UPDATE_BASELINE=1 bash mobile/scripts/check_nostr_id_log_truncation.sh
# Run (from repo root or mobile/):
#   bash mobile/scripts/check_nostr_id_log_truncation.sh
# List the individual sites:
#   dart run scripts/lib/nostr_id_log_truncation_detector.dart \
#     lib packages test integration_test --detail

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TAB="$(printf '\t')"

RATCHET_LABEL="nostr_id_log_truncation"
PATH_PREFIX="${NOSTR_ID_LOG_TRUNCATION_PATH_PREFIX:-$MOBILE_DIR}"
BASELINE_FILE="${NOSTR_ID_LOG_TRUNCATION_BASELINE_FILE:-$SCRIPT_DIR/baseline/nostr_id_log_truncation.txt}"
BASELINE_REPO_PATH="${NOSTR_ID_LOG_TRUNCATION_BASELINE_REPO_PATH:-mobile/scripts/baseline/nostr_id_log_truncation.txt}"
BASE_REF="${NOSTR_ID_LOG_TRUNCATION_BASELINE_BASE_REF:-origin/main}"
ALLOW_NO_BASE="${NOSTR_ID_LOG_TRUNCATION_ALLOW_NO_BASE:-0}"
ALLOW_NO_BASE_VAR="NOSTR_ID_LOG_TRUNCATION_ALLOW_NO_BASE"
DART_BIN="${NOSTR_ID_LOG_TRUNCATION_DART:-dart}"

# Space-separated roots. The rule names "code, logs, tests, analytics, or debug
# output", so app code, every workspace package, and the test trees are all in
# scope — all four are already at zero.
SCAN_DIR="${NOSTR_ID_LOG_TRUNCATION_SCAN_DIR:-$MOBILE_DIR/lib $MOBILE_DIR/packages $MOBILE_DIR/test $MOBILE_DIR/integration_test}"

NEW_HINT="For a PUBLIC identifier, log the whole value: drop the .substring()/preview local or mask helper, remove a literal ellipsis immediately after the interpolation, and interpolate the value itself. For a SECRET (nsec, ncryptsec, a private/signing key), never log the value: omit it or replace it with a non-value presence/status message. For UI, shorten at the widget with maxLines + TextOverflow.ellipsis so the copied value stays exact. AGENTS.md → Nostr And Async Rules; #3372."
STALE_HINT="A file stopped shortening a Nostr identifier on its way into a log."
FOOTER="Shortened public Nostr identifiers and disclosed Nostr secrets are frozen at zero.
A truncated id looks correlatable and is not: it cannot be grepped against
relay logs or matched to a funnelcake row. See AGENTS.md (Nostr And Async
Rules) and #3372. Inspect the sites with:
  dart run scripts/lib/nostr_id_log_truncation_detector.dart lib packages test integration_test --detail"

# Print "relpath<TAB>count" for every file with at least one site. Runs from
# MOBILE_DIR so the detector resolves package:analyzer from the app's config.
emit_current() {
  (
    cd "$MOBILE_DIR"
    # shellcheck disable=SC2086
    "$DART_BIN" run scripts/lib/nostr_id_log_truncation_detector.dart \
      $SCAN_DIR --path-prefix "$PATH_PREFIX"
  ) | LC_ALL=C sort -t "$TAB" -k1,1
}

print_baseline_header() {
  cat <<EOF
# Frozen baseline: Dart files under mobile/lib, mobile/packages, mobile/test and
# mobile/integration_test that shorten a public Nostr identifier or disclose a
# Nostr secret in a log/debug sink (format: relpath<TAB>count).
# The list is intentionally EMPTY — #3372 closed all 19 sites, so any entry here
# is a regression. Generated by scripts/check_nostr_id_log_truncation.sh from
# scripts/lib/nostr_id_log_truncation_detector.dart. Fix the log call rather
# than regenerating this file: log public identifiers whole and omit secrets.
# UI-side shortening is NOT counted (display sink, not a log sink).
# Issue: #3372.
EOF
}

# shellcheck source=lib/numeric_ratchet.sh
source "$SCRIPT_DIR/lib/numeric_ratchet.sh"
run_numeric_ratchet
