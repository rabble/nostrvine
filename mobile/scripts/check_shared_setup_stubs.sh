#!/usr/bin/env bash
# Shared-setUp stub ceiling ratchet (#8399, follow-up to #8170 / #7324): every
# test file whose file-level or outermost-group `setUp` registers 10 or more
# mocktail stubs inherited by descendant groups is frozen at its current count
# in scripts/baseline/shared_setup_stubs.txt, a per-file CEILING that may only
# ever DECREASE.
#
# Why: a stub in a shared `setUp` is invisible at every call site that inherits
# it. Nothing in a failing test's own body hints that a decision was replaced by
# a constant, so a class of bug can become unobservable across the whole file.
# #7324 shipped that way — `hasMatchingMessage` was pinned to `false` in
# dm_repository_test.dart's shared setUp, so two identical messages arriving
# seconds apart both persisted in test and only one persisted in production, and
# none of the 421 tests in that file could see it. The regression test for it had
# to be written in a separate file against a real DAO (#8169).
#
# The shape also accretes silently. That same block grew from 6 stubs to 21
# across 13 different PRs, none of which added enough to look wrong in review.
# That is the specific failure a ratchet catches and code review does not.
#
# What is counted: `when(` / `whenListen(` inside a `setUp` / `setUpAll` at
# group-nesting depth 0 or 1, when the scope it governs also contains descendant
# groups that declare tests. Direct calls and tear-offs of same-file helpers are
# followed: extracting a shared setUp body does not reduce its reach or count. A
# leaf group's own setUp is NOT counted — the stub and the tests it governs are
# adjacent, which is the shape this pushes work toward. See
# scripts/lib/shared_setup_stub_detector.dart for the full rule.
#
# The 10-stub floor is deliberate. The median flagged file carries 3, which is
# ordinary fixture wiring rather than hidden decisions; the tail runs to 35.
# Freezing all 287 files that register any inherited stub would be four times the
# largest existing baseline in this repo and would block routine test authoring,
# which invites workarounds. A file crossing 10 becomes a new key and fails.
#
# The fix is to declare the stub in the groups that depend on it, ideally via a
# named helper so a group states its dependency in a line:
#     setUp(stubSendPolicyPermitsEveryone);
# packages/dm_repository/test/src/dm_repository_test.dart is the worked example.
#
# One caution when removing a stub: a green test count is NOT sufficient
# evidence it was unused. Where production CATCHES an unstubbed member's throw,
# removing the stub keeps every test green while silently running the file
# against an error branch. Diff the run's logs too:
#     grep -oE "type 'Null' is not a subtype of type '" <run.log> | wc -l
#
# Per-key NUMERIC ceiling: a file may drop stubs freely while at or above the
# floor without churning the baseline; growth, a new file, a raised ceiling, or
# dropping below the floor (STALE — regenerate to lock the win) fails.
#
# Regenerate after RELOCATING stubs (never to raise):
#   UPDATE_BASELINE=1 bash mobile/scripts/check_shared_setup_stubs.sh
# Run (from repo root or mobile/): bash mobile/scripts/check_shared_setup_stubs.sh
# List a file's sites:
#   dart run scripts/lib/shared_setup_stub_detector.dart test --detail

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TAB="$(printf '\t')"

RATCHET_LABEL="shared_setup_stubs"
MIN_COUNT="${SHARED_SETUP_STUBS_MIN_COUNT:-10}"
PATH_PREFIX="${SHARED_SETUP_STUBS_PATH_PREFIX:-$MOBILE_DIR}"
BASELINE_FILE="${SHARED_SETUP_STUBS_BASELINE_FILE:-$SCRIPT_DIR/baseline/shared_setup_stubs.txt}"
BASELINE_REPO_PATH="${SHARED_SETUP_STUBS_BASELINE_REPO_PATH:-mobile/scripts/baseline/shared_setup_stubs.txt}"
BASE_REF="${SHARED_SETUP_STUBS_BASELINE_BASE_REF:-origin/main}"
ALLOW_NO_BASE="${SHARED_SETUP_STUBS_ALLOW_NO_BASE:-0}"
ALLOW_NO_BASE_VAR="SHARED_SETUP_STUBS_ALLOW_NO_BASE"
DART_BIN="${SHARED_SETUP_STUBS_DART:-dart}"

NEW_HINT="A shared setUp must not gain stubs, and a file must not cross ${MIN_COUNT} inherited stubs. Declare the stub in the groups that depend on it — a named helper called as setUp(stubFooAllows); keeps it to one line per depending group. Extracting the same shared setUp body into a helper does not reduce its reach or its count. See packages/dm_repository/test/src/dm_repository_test.dart and #8399."
STALE_HINT="A file relocated its shared stubs below the ${MIN_COUNT}-stub floor."
FOOTER="Inherited shared-setUp stub counts are frozen per file and may only decrease.
A stub in a shared setUp is invisible at every call site that inherits it; that
is how #7324 stayed green across a whole file. Declare it in the groups that
need it. Inspect a file's sites with:
  dart run scripts/lib/shared_setup_stub_detector.dart test --detail"

SCAN_DIRS_DEFAULT="test integration_test packages"
SCAN_DIRS="${SHARED_SETUP_STUBS_SCAN_DIRS:-$SCAN_DIRS_DEFAULT}"

emit_current() {
  (
    cd "$MOBILE_DIR"
    # shellcheck disable=SC2086
    "$DART_BIN" run scripts/lib/shared_setup_stub_detector.dart \
      $SCAN_DIRS --path-prefix "$PATH_PREFIX" --min-count "$MIN_COUNT"
  ) | LC_ALL=C sort -t "$TAB" -k1,1
}

print_baseline_header() {
  cat <<EOF
# Frozen baseline: test files whose file-level or outermost-group setUp
# reaches ${MIN_COUNT} or more mocktail stubs inherited by descendant groups,
# each with its current count as a CEILING (format: relpath<TAB>count).
# Generated by scripts/check_shared_setup_stubs.sh from
# scripts/lib/shared_setup_stub_detector.dart. A ceiling may only SHRINK; more
# stubs, a new file, or a raised ceiling fails CI vs ${BASE_REF}. The fix is to
# declare the stub in the groups that depend on it (#8399, #8170, #7324).
# Regenerate after relocating stubs:
#   UPDATE_BASELINE=1 bash scripts/check_shared_setup_stubs.sh
EOF
}

# shellcheck source=lib/numeric_ratchet.sh
source "$SCRIPT_DIR/lib/numeric_ratchet.sh"
run_numeric_ratchet
