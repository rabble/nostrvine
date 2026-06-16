#!/usr/bin/env bash
# Fails CI if a test the very_good optimizer MERGES into the shared isolate
# installs a process-global platform/package singleton WITHOUT restoring it.
# An unrestored install persists into every later merged test in the shared
# isolate, surfacing as an order-dependent failure cross-attributed to an
# unrelated test. This generalizes the single-global precedent
# check_http_overrides_isolation.sh (PR #5163) to the class of
# `<Singleton>.instance` test seams behind the #5159 / #5180 cascades
# (parent #3137).
#
# A file is in the merge UNLESS it is tagged @Tags(['skip_very_good_optimization']).
# Being under test/manual/ does NOT exclude it — only the tag does (the very_good
# --optimization globber does not honor dart_test.yaml's exclude: test/manual/**).
#
# Policy: HARD-ZERO. Every untagged *_test.dart that installs a candidate global
# must, within the same file, SNAPSHOT the original (a `<id> = <Global>` read)
# and RESTORE it (a `<Global> = <id>` write, e.g. in tearDown / tearDownAll).
# Unlike check_http_overrides_isolation.sh — which rejects even a correct restore
# because a nulled HttpOverrides 400-mock is itself the hazard while the file
# runs — a within-file restore PASSES here: for these singletons the tearDown
# returns the global to its prior value before the next merged file runs.
# Detection is a grep proxy (it cannot prove the restore is reachable or lives
# in a tearDown); the snapshot+restore pair is the canonical fix and the tag is
# the escape hatch for tests that legitimately cannot restore (real plugin /
# integration tests).
#
# Scope: only `<Singleton>.instance` assignments (the class that caused the
# #5159 cascades). A read of the global, a comment mention, and `==` / `=>` do
# not match. lib/ is out of scope. Only `*_test.dart` files are scanned, so
# non-test helpers — e.g. test/test_setup.dart, which installs the suite-wide
# PathProviderPlatform mock by design — are not flagged. HttpOverrides.global
# keeps its own dedicated STRICT gate and is intentionally not handled here.
#
# Usage:
#   bash mobile/scripts/check_process_global_mutations.sh
#   (run from the repository root or from mobile/)
set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Candidate process-global singletons (Tier-2). Extend as new leak classes are
# found. Each entry is the ERE core, matched after an optional `<prefix>.`.
GLOBALS=(
  'PathProviderPlatform\.instance'
  'ProVideoEditor\.instance'
  'WebViewPlatform\.instance'
  'UrlLauncherPlatform\.instance'
  'VideoPlayerPlatform\.instance'
  'FirebasePlatform\.instance'
)

violations=""

for core in "${GLOBALS[@]}"; do
  # Fast pre-filter: *_test.dart files mentioning the global at all.
  files=$(grep -rlE --include='*_test.dart' "$core" "$MOBILE_DIR/test" || true)
  for f in $files; do
    # Comment-stripped view: drop lines whose first non-blank chars are // or ///
    # (defends doc-comment install snippets and fully commented-out tests).
    body=$(grep -vE '^[[:space:]]*//' "$f" || true)

    # A real ASSIGNMENT (install or restore): (<prefix>.)?CORE = , where `=` is
    # not `==` / `=>`. `=` may sit at end-of-line (dart format keeps the LHS
    # token on its own line for a multi-line RHS).
    if ! grep -qE "(^|[^A-Za-z0-9_.])([A-Za-z_][A-Za-z0-9_]*\.)?${core}[[:space:]]*=([^=>]|$)" <<<"$body"; then
      continue
    fi

    # Tagged out of the merge? Line-anchored so a commented-out (// @Tags(...))
    # or doc-mention does NOT satisfy the gate — mirrors how the Dart test
    # runner reads the library annotation.
    if grep -qE "^[[:space:]]*@Tags\([^)]*skip_very_good_optimization" "$f"; then
      continue
    fi

    # SNAPSHOT (capture-read): the global appears on the RHS of an assignment
    # (`<id> = <Global>`), i.e. the original was captured into a local.
    has_capture=0
    if grep -qE "=[[:space:]]*([A-Za-z_][A-Za-z0-9_]*\.)?${core}([^A-Za-z0-9_]|$)" <<<"$body"; then
      has_capture=1
    fi

    # RESTORE (restore-write): the global is assigned a BARE identifier
    # (`<Global> = original;` block form, or `=> <Global> = original)` arrow
    # form), which distinguishes a restore from a `<Global> = SomeFake()` install.
    has_restore=0
    if grep -qE "([A-Za-z_][A-Za-z0-9_]*\.)?${core}[[:space:]]*=[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*[;)]" <<<"$body"; then
      has_restore=1
    fi

    if [[ "$has_capture" -eq 0 || "$has_restore" -eq 0 ]]; then
      rel="${f#"$MOBILE_DIR"/}"
      disp="${core//\\/}"
      violations="$violations  $rel  ($disp)"$'\n'
    fi
  done
done

if [[ -n "$violations" ]]; then
  echo "FAIL [process_global_mutations]: untagged test installs a process-global"
  echo "singleton without a within-file restore:"
  printf '%s' "$violations" | sed '/^$/d'
  echo ""
  echo "Installing <Singleton>.instance in a MERGED (untagged) test without"
  echo "restoring it leaks the fake into every later test in the shared"
  echo "very_good --optimization isolate, causing order-dependent flakes"
  echo "(generalizes PR #5163; cascades #5159 / #5180; parent #3137)."
  echo ""
  echo "Remediation — pick one:"
  echo "  (a) Snapshot the original and restore it within the file:"
  echo "        late <Type> original;"
  echo "        setUp(() { original = <Global>.instance; <Global>.instance = <fake>; });"
  echo "        tearDown(() { <Global>.instance = original; });"
  echo "      (use setUpAll / tearDownAll for a setUpAll install)."
  echo "  (b) Real-plugin / integration test that cannot restore: tag it so it"
  echo "      stays out of the merge (annotation BEFORE the first import):"
  echo "        @Tags(['skip_very_good_optimization', 'integration'])"
  echo "      then bump mobile/test/vgv_tag_baseline.txt if the tag count rises."
  exit 1
fi

echo "OK: no untagged test leaks a process-global singleton."
