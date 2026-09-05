#!/usr/bin/env bash
# Unpinned "unchanged" assertion ratchet (#8617): a test whose only assertion
# compares a re-read of state with a local holding an earlier read of the same
# state, without ever pinning what that local held, is frozen at ZERO per file
# in scripts/baseline/unpinned_unchanged_assertions.txt. The baseline is
# intentionally EMPTY — #8617 fixed every site — so any entry here is a
# regression.
#
# Why: the shape passes when the method under test never runs at all.
#
#   service.markAuthShellReady();
#   final firstTime = service.authShellReadyTime;
#   service.markAuthShellReady();
#   expect(service.authShellReadyTime, equals(firstTime));
#
# With markAuthShellReady() replaced by a no-op, authShellReadyTime stays null
# and the assertion compares null with null. #8617 proved that by mutation:
# the file's other two tests went red and this one stayed green. The same
# holds for a counter that stays 0, a list that stays empty, or a notifier
# whose value never landed. .claude/rules/testing.md: "If the test would still
# pass with the feature broken, it tests nothing."
#
# What clears a site: assert what the baseline held, anywhere in the same
# test — `expect(firstTime, isNotNull)`, `expect(count, greaterThan(0))`,
# `expect(rows, hasLength(2))`, an expect on a member of the read expression
# (`expect(cubit.state.status, ready)` before `final last = cubit.state`), or
# a `firstTime!` that would throw on null. The pin is one line and turns the
# test into one that fails when the mechanism is dead.
#
# Only a pair that is the test's ONLY assertion counts. A pair sitting beside
# a real assertion is out of scope here for the same reason a tautology beside
# a real assertion is out of scope for check_placeholder_tests.sh: the test as
# a whole can still fail. Those sites are listed by `--all` and are worth a
# pin when touched, but a guard that cries wolf gets switched off.
#
# check_placeholder_tests.sh cannot see this shape: it freezes LITERAL
# tautologies (`expect(true, isTrue)`), and here both operands are derived from
# the state under test, so the assertion is vacuous only when that state is
# absent. Deciding that needs the whole test body, which is why the detector
# (scripts/lib/unpinned_unchanged_assertion_detector.dart) is a real Dart AST:
# `dart format` wraps the local, the re-read and the matcher onto different
# lines, and whether the pair is pinned is a property of the body, not of a
# line. Pinned by test/tools/unpinned_unchanged_assertion_detector_test.dart.
#
# Regenerate ONLY after an intentional, reviewed change:
#   UPDATE_BASELINE=1 bash mobile/scripts/check_unpinned_unchanged_assertions.sh
# Run (from repo root or mobile/): bash mobile/scripts/check_unpinned_unchanged_assertions.sh
# List the individual sites (add --all for pairs beside other assertions):
#   dart run scripts/lib/unpinned_unchanged_assertion_detector.dart test integration_test packages --path-prefix . --detail

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TAB="$(printf '\t')"

RATCHET_LABEL="unpinned_unchanged_assertions"
BASELINE_FILE="${UNPINNED_UNCHANGED_ASSERTIONS_BASELINE_FILE:-$SCRIPT_DIR/baseline/unpinned_unchanged_assertions.txt}"
BASELINE_REPO_PATH="${UNPINNED_UNCHANGED_ASSERTIONS_BASELINE_REPO_PATH:-mobile/scripts/baseline/unpinned_unchanged_assertions.txt}"
BASE_REF="${UNPINNED_UNCHANGED_ASSERTIONS_BASELINE_BASE_REF:-origin/main}"
ALLOW_NO_BASE="${UNPINNED_UNCHANGED_ASSERTIONS_ALLOW_NO_BASE:-0}"
ALLOW_NO_BASE_VAR="UNPINNED_UNCHANGED_ASSERTIONS_ALLOW_NO_BASE"
DART_BIN="${UNPINNED_UNCHANGED_ASSERTIONS_DART:-dart}"

# Scan roots, relative to MOBILE_DIR. `packages` is scanned whole and filtered
# to test/ and integration_test/ segments by the detector.
SCAN_DIRS="${UNPINNED_UNCHANGED_ASSERTIONS_SCAN_DIRS:-test integration_test packages}"

NEW_HINT="An 'unchanged' assertion needs its baseline pinned. Before the act, assert what the local held — expect(first, isNotNull), expect(count, greaterThan(0)), expect(rows, hasLength(2)) — so the test fails when the method under test is a no-op. See .claude/rules/testing.md ('A Test Must Be Able to Fail') and #8617."
STALE_HINT="A file stopped carrying unpinned unchanged-assertions."
FOOTER="Unpinned 'unchanged' assertions are frozen at zero.
See .claude/rules/testing.md ('A Test Must Be Able to Fail') and #8617.
Inspect the sites with:
  dart run scripts/lib/unpinned_unchanged_assertion_detector.dart test integration_test packages --path-prefix . --detail"

# Print "relpath<TAB>count" for every file with at least one site. Runs from
# MOBILE_DIR so the detector resolves package:analyzer from the app's config.
emit_current() {
  (
    cd "$MOBILE_DIR"
    # shellcheck disable=SC2086
    "$DART_BIN" run scripts/lib/unpinned_unchanged_assertion_detector.dart \
      $SCAN_DIRS --path-prefix "$MOBILE_DIR"
  ) | LC_ALL=C sort -t "$TAB" -k1,1
}

print_baseline_header() {
  cat <<EOF
# Frozen baseline: test files under mobile/test, mobile/integration_test and
# mobile/packages/*/test containing a test whose only assertion compares a
# re-read of state with an earlier read of it that was never pinned
# (format: relpath<TAB>count). Generated by
# scripts/check_unpinned_unchanged_assertions.sh from
# scripts/lib/unpinned_unchanged_assertion_detector.dart.
#
# The list is intentionally EMPTY: #8617 fixed every site, so any entry here
# is a regression. Fix the test rather than regenerating this file — pin the
# baseline (expect(first, isNotNull), expect(count, greaterThan(0))) before
# the act, so the test fails when the method under test is a no-op.
#
# Only a pair that is the test's ONLY assertion is counted; a pair beside a
# real assertion is listed by the detector's --all flag but not frozen here.
#
# Issue: #8617.
EOF
}

# shellcheck source=lib/numeric_ratchet.sh
source "$SCRIPT_DIR/lib/numeric_ratchet.sh"
run_numeric_ratchet
