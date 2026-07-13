#!/usr/bin/env bash
# Fails CI if a test the very_good optimizer MERGES into the shared isolate
# mutates a process-global WITHOUT restoring it. An unrestored mutation persists
# into every later merged test in the shared isolate, surfacing as an
# order-dependent failure cross-attributed to an unrelated test. This generalizes
# the single-global precedent check_http_overrides_isolation.sh (PR #5163) to the
# classes of test seams behind the #5159 / #5180 cascades (parent #3137) and the
# Tier-3/Tier-4 residual (#5185).
#
# A file is in the merge UNLESS it is tagged @Tags(['skip_very_good_optimization']).
# Being under test/manual/ does NOT exclude it — only the tag does (the very_good
# --optimization globber does not honor dart_test.yaml's exclude: test/manual/**).
#
# Two detection classes, each HARD-ZERO (no baseline, no tolerated debt):
#
#   1. CAPTURE-RESTORE (GLOBALS) — `<Singleton>.instance` and static hooks whose
#      documented resting value is the *prior runtime value*. Every untagged
#      *_test.dart that installs one must, within the same file, SNAPSHOT the
#      original (a `<id> = <Global>` read) and RESTORE it (a `<Global> = <id>`
#      bare-identifier write, e.g. in tearDown / tearDownAll / addTearDown).
#      Unlike check_http_overrides_isolation.sh — which rejects even a correct
#      restore because a nulled HttpOverrides 400-mock is itself the hazard while
#      the file runs — a within-file restore PASSES here.
#
#   2. RESET-TO-DEFAULT (RESET_TO_DEFAULT_GLOBALS) — top-level debug overrides /
#      test-injection setters whose documented resting value is a compile-time
#      DEFAULT LITERAL (all `null` today), so there is no prior to snapshot. A
#      file that installs a NON-default value must, within the same file, assign
#      the global back to its default literal (`<Global> = <default>`, block or
#      `=> <Global> = <default>)` arrow form). No capture is required; a file
#      whose only assignment IS the default (e.g. a lone `= null`) is harmless
#      and passes.
#
# Detection is a grep proxy for BOTH classes: it cannot prove the restore is
# reachable or lives in a tearDown (an inline end-of-body reset satisfies the
# grep but not a mid-test throw). The snapshot+restore / reset-to-default pair is
# the canonical fix; the tag is the escape hatch for tests that legitimately
# cannot restore (real plugin / integration tests).
#
# Scope: assignments only (a read, a comment mention, `==`, `=>` do not match).
# lib/ is out of scope. Only `*_test.dart` under mobile/test is scanned, so
# non-test helpers — e.g. test/test_setup.dart, which installs the suite-wide
# PathProviderPlatform mock by design — are not flagged, and packages/*/test
# (each its own separate merged isolate — issue #5838) is out of scope here.
# HttpOverrides.global keeps its own dedicated STRICT gate (check_http_overrides_isolation.sh)
# and is intentionally not handled here.
#
# GoogleFonts.config.allowRuntimeFetching is intentionally NOT gated: the shared
# test harness sets it `false` suite-wide and `false` is the resting value every
# test wants (benign-monotonic), so an un-restored `= false` is not a hazard.
#
# Usage:
#   bash mobile/scripts/check_process_global_mutations.sh
#   bash mobile/scripts/check_process_global_mutations.sh --selftest
#   (run from the repository root or from mobile/)
set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Class 1 — capture-restore globals. Each entry is the ERE core, matched after an
# optional `<prefix>.`. (Tier-2 `<Singleton>.instance` + Tier-4 static hooks.)
GLOBALS=(
  'PathProviderPlatform\.instance'
  'ProVideoEditor\.instance'
  'WebViewPlatform\.instance'
  'UrlLauncherPlatform\.instance'
  'VideoPlayerPlatform\.instance'
  'FirebasePlatform\.instance'
  'FlutterError\.onError'
  'Bloc\.observer'
)

# Class 2 — reset-to-default globals, `core:defaultLiteral` (colon-delimited so
# bash 3.2 — the macOS pre-commit hook — needs no associative arrays). The
# default literal must be a regex-safe token; all defaults are `null` today.
#
# Note: debugDefaultTargetPlatformOverride is also a Flutter *foundation debug
# var* — in a `testWidgets` test, `debugAssertAllFoundationVarsUnset` (foundation
# debug.dart) already fails the test at end-of-body if it is left set, so a leak
# there is loud, not silent, and only an INLINE reset works (that assertion runs
# before tearDown/addTearDown). This gate still earns its keep for it by covering
# plain `test()` usage, which has no such framework guard; the other entries
# below have no framework guard at all.
RESET_TO_DEFAULT_GLOBALS=(
  'debugDefaultTargetPlatformOverride:null'
  'debugImageCacheOverride:null'
  'debugUsesAppleAppStoreTipPolicyOverride:null'
  'VideoEditorRenderService\.renderVideoOverride:null'
  'VideoEditorRenderService\.renderVideoToClipOverride:null'
  'NativeProofModeService\.proofFileOverride:null'
  'InfiniteVideoFeed\.debugIsSupportedOverride:null'
)

# Scan target — overridable for --selftest; defaults to the app merged-isolate tree.
SCAN_DIR="${SCAN_DIR:-$MOBILE_DIR/test}"

run_scan() {
  local violations="" core files f body def

  # --- Class 1: capture-restore ---
  for core in "${GLOBALS[@]}"; do
    files=$(grep -rlE --include='*_test.dart' "$core" "$SCAN_DIR" || true)
    for f in $files; do
      body=$(grep -vE '^[[:space:]]*//' "$f" || true)

      # A real ASSIGNMENT (install or restore): (<prefix>.)?CORE = , not == / =>.
      if ! grep -qE "(^|[^A-Za-z0-9_.])([A-Za-z_][A-Za-z0-9_]*\.)?${core}[[:space:]]*=([^=>]|$)" <<<"$body"; then
        continue
      fi
      # Tagged out of the merge? Line-anchored, whole-file (a @Tags below class
      # defs / above main() still counts, matching the very_good text-scan).
      if grep -qE "^[[:space:]]*@Tags\([^)]*skip_very_good_optimization" "$f"; then
        continue
      fi
      # SNAPSHOT: the global appears on the RHS of an assignment (captured local).
      local has_capture=0
      if grep -qE "=[[:space:]]*([A-Za-z_][A-Za-z0-9_]*\.)?${core}([^A-Za-z0-9_]|$)" <<<"$body"; then
        has_capture=1
      fi
      # RESTORE: the global assigned a BARE identifier (block `= original;` or
      # arrow `=> <Global> = original)`), distinguishing a restore from a
      # `<Global> = SomeFake()` install.
      local has_restore=0
      if grep -qE "([A-Za-z_][A-Za-z0-9_]*\.)?${core}[[:space:]]*=[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*[;)]" <<<"$body"; then
        has_restore=1
      fi
      if [[ "$has_capture" -eq 0 || "$has_restore" -eq 0 ]]; then
        rel="${f#"$MOBILE_DIR"/}"
        disp="${core//\\/}"
        violations="$violations  $rel  ($disp) [capture-restore]"$'\n'
      fi
    done
  done

  # --- Class 2: reset-to-default ---
  local entry
  for entry in "${RESET_TO_DEFAULT_GLOBALS[@]}"; do
    core="${entry%%:*}"
    def="${entry##*:}"
    files=$(grep -rlE --include='*_test.dart' "$core" "$SCAN_DIR" || true)
    for f in $files; do
      body=$(grep -vE '^[[:space:]]*//' "$f" || true)

      if ! grep -qE "(^|[^A-Za-z0-9_.])([A-Za-z_][A-Za-z0-9_]*\.)?${core}[[:space:]]*=([^=>]|$)" <<<"$body"; then
        continue
      fi
      if grep -qE "^[[:space:]]*@Tags\([^)]*skip_very_good_optimization" "$f"; then
        continue
      fi
      # RESET-TO-DEFAULT present: `<Global> = <default>` (block or arrow form).
      local has_default_reset=0
      if grep -qE "([A-Za-z_][A-Za-z0-9_]*\.)?${core}[[:space:]]*=[[:space:]]*${def}[[:space:]]*[;)]" <<<"$body"; then
        has_default_reset=1
      fi
      # NON-default install present: an assignment line that is NOT a reset to the
      # default literal (so a file whose only assignment is the default passes).
      local has_nondefault_install=0
      if grep -E "(^|[^A-Za-z0-9_.])([A-Za-z_][A-Za-z0-9_]*\.)?${core}[[:space:]]*=([^=>]|$)" <<<"$body" \
         | grep -qvE "([A-Za-z_][A-Za-z0-9_]*\.)?${core}[[:space:]]*=[[:space:]]*${def}[[:space:]]*[;)]"; then
        has_nondefault_install=1
      fi
      if [[ "$has_nondefault_install" -eq 1 && "$has_default_reset" -eq 0 ]]; then
        rel="${f#"$MOBILE_DIR"/}"
        disp="${core//\\/}"
        violations="$violations  $rel  ($disp) [reset-to-default → $def]"$'\n'
      fi
    done
  done

  if [[ -n "$violations" ]]; then
    echo "FAIL [process_global_mutations]: untagged merged test mutates a"
    echo "process-global without a within-file restore:"
    printf '%s' "$violations" | sed '/^$/d'
    echo ""
    echo "Mutating one of these globals in a MERGED (untagged) test without"
    echo "restoring it leaks the value into every later test in the shared"
    echo "very_good --optimization isolate, causing order-dependent flakes"
    echo "(generalizes PR #5163; cascades #5159 / #5180; parent #3137; residual #5185)."
    echo ""
    echo "Remediation — pick one:"
    echo "  (a) [capture-restore] Snapshot the original and restore it in the file:"
    echo "        late <Type> original;"
    echo "        setUp(() { original = <Global>; <Global> = <fake>; });"
    echo "        tearDown(() { <Global> = original; });"
    echo "  (b) [reset-to-default] Assign the global back to its default in a"
    echo "      guaranteed-reachable tearDown/addTearDown (NOT an inline end-of-body"
    echo "      line, which a mid-test throw would skip):"
    echo "        addTearDown(() => debugDefaultTargetPlatformOverride = null);"
    echo "  (c) Real-plugin / integration test that cannot restore: tag it so it"
    echo "      stays out of the merge (annotation BEFORE the first import):"
    echo "        @Tags(['skip_very_good_optimization', 'integration'])"
    echo "      then bump mobile/test/vgv_tag_baseline.txt if the tag count rises."
    return 1
  fi

  echo "OK: no untagged test leaks a process-global (capture-restore + reset-to-default)."
  return 0
}

# --- self-test: run the REAL scan over synthetic fixtures, assert exit codes ---
run_selftest() {
  local rc=0 tmp got desc want
  _case() {
    desc="$1"; want="$2"; local content="$3"
    tmp="$(mktemp -d)"
    printf '%s' "$content" > "$tmp/fixture_test.dart"
    if SCAN_DIR="$tmp" bash "$0" >/dev/null 2>&1; then got=0; else got=$?; fi
    rm -rf "$tmp"
    if [[ "$got" -eq "$want" ]]; then
      echo "  ok   ($got) $desc"
    else
      echo "  FAIL (got $got, want $want) $desc"; rc=1
    fi
  }

  echo "self-test:"
  _case "capture-restore leaker (Bloc.observer install, no restore) → FAIL" 1 \
'import "x";
void main() { Bloc.observer = MyObserver(); }
'
  _case "capture-restore correct (snapshot + restore) → PASS" 0 \
'import "x";
void main() {
  final prior = Bloc.observer;
  Bloc.observer = MyObserver();
  addTearDown(() => Bloc.observer = prior);
}
'
  _case "reset-to-default leaker (debugDefaultTargetPlatformOverride, no = null) → FAIL" 1 \
'import "x";
void main() { debugDefaultTargetPlatformOverride = TargetPlatform.iOS; }
'
  _case "reset-to-default correct (= null in tearDown) → PASS" 0 \
'import "x";
void main() {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  tearDown(() { debugDefaultTargetPlatformOverride = null; });
}
'
  _case "reset-to-default arrow form (=> = null)) → PASS" 0 \
'import "x";
void main() {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
}
'
  _case "tagged leaker (skip_very_good_optimization, tag below class defs) → PASS" 0 \
'class _Foo {}
@Tags(["skip_very_good_optimization"])
import "x";
void main() { debugDefaultTargetPlatformOverride = TargetPlatform.iOS; }
'
  _case "commented-out install → PASS" 0 \
'import "x";
void main() {
  // debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  // Bloc.observer = MyObserver();
}
'
  _case "lone default assignment (= null only, no install) → PASS" 0 \
'import "x";
void main() { setUp(() { debugDefaultTargetPlatformOverride = null; }); }
'
  return $rc
}

if [[ "${1:-}" == "--selftest" ]]; then
  run_selftest
  exit $?
fi

run_scan
exit $?
