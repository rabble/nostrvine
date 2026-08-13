#!/usr/bin/env bash
# Maestro copy-drift guard: every English string the Maestro suite asserts or
# taps is bound to the ARB key it came from in
# scripts/baseline/maestro_copy_manifest.txt, and this check fails when the
# current value of that key in lib/l10n/app_en.arb no longer appears in the
# bound flow file. Between 2026-03 and 2026-08 the suite silently rotted
# because copy changes and flow changes live in different files with nothing
# failing when they diverged; this is the failure that should have fired.
#
# app_en.arb is the ONLY source of truth for English copy. Two failure modes:
#   DRIFT        — a bound ARB key's current value is absent from the bound
#                  flow file (copy changed under the suite, or the flow edited
#                  without regenerating). The message names the key, the flow
#                  file, and the current ARB value to adopt.
#   UNREGISTERED — a flow literal exactly matches a non-parameterized ARB
#                  value but has no manifest binding (new assertion added
#                  without registering). Regenerate to register it.
#
# Manifest format (one binding per line, '#'-comments allowed):
#   <arb_key><TAB><flow path relative to mobile/>[<TAB>rendered:<literal>]
# The optional third column is for PARAMETERIZED ARB values (ICU placeholders
# like {count}): flows assert the rendered string, not the template, so the
# rendered literal is recorded by hand and checked verbatim instead. These
# entries survive regeneration; everything else is auto-derived.
#
# Element ids (id: ...) are NOT copy and are out of scope by design; regex
# selectors (e.g. "Search.*") never exactly equal an ARB value and so never
# bind — that is conservative on purpose, not a gap to close with fuzzy
# matching.
#
# Regenerate after an intentional copy change (review the printed diff of
# added/removed bindings — regeneration re-blesses whatever ARB says today):
#   UPDATE_BASELINE=1 bash mobile/scripts/check_maestro_copy_drift.sh
# Regeneration REFUSES to drop a binding whose ARB key still exists and whose
# flow file is still present: a vanished binding is drift being erased, not
# cleanup. If the flow genuinely stopped asserting that key's copy, say so
# explicitly: ACCEPT_REMOVALS=1 UPDATE_BASELINE=1 bash ...
# The check also ratchets against the base ref (MAESTRO_COPY_DRIFT_BASE_REF,
# default origin/main): a binding present on the base manifest may not vanish
# from the branch manifest while its ARB key exists — that closes the bypass
# where a PR regenerates away its own regression. Bootstrap: skipped with a
# note until the manifest lands on the base ref. Fails closed when the base
# is unloadable; MAESTRO_COPY_DRIFT_ALLOW_NO_BASE=1 is the local-only opt-out.
# Usage (from the repo root or mobile/): bash mobile/scripts/check_maestro_copy_drift.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ARB_FILE="$MOBILE_DIR/lib/l10n/app_en.arb"
E2E_DIR="$MOBILE_DIR/e2e/maestro"
MANIFEST_FILE="$SCRIPT_DIR/baseline/maestro_copy_manifest.txt"
MANIFEST_REPO_PATH="mobile/scripts/baseline/maestro_copy_manifest.txt"

MODE="check"
if [[ "${UPDATE_BASELINE:-0}" == "1" ]]; then
  MODE="regen"
fi

python3 - "$MODE" "$ARB_FILE" "$E2E_DIR" "$MANIFEST_FILE" <<'PYEOF'
import json
import os
import re
import sys

mode, arb_path, e2e_dir, manifest_path = sys.argv[1:5]

def norm(s):
    # YAML folding and source wrapping can split one logical string across
    # whitespace; compare on collapsed whitespace, both sides.
    return " ".join(s.split())

# ---------- load ARB (the only source of truth for English copy) ----------
with open(arb_path, encoding="utf-8") as fh:
    arb_raw = json.load(fh)

exact_values = {}      # value -> [keys] for non-parameterized strings
param_values = {}      # key -> template (contains ICU {placeholder})
for key, val in arb_raw.items():
    if key.startswith("@") or not isinstance(val, str):
        continue
    if "{" in val:
        param_values[key] = val
    else:
        exact_values.setdefault(norm(val), []).append(key)

all_keys = {k for ks in exact_values.values() for k in ks} | set(param_values)

# ---------- extract asserted/tapped literals from flow YAML ----------
COMMAND_SCALAR = re.compile(
    r"^\s*-\s*(?:assertVisible|assertNotVisible|tapOn|longPressOn):\s*(?P<v>.+?)\s*$"
)
TEXT_PROP = re.compile(r"^\s*text:\s*(?P<v>.+?)\s*$")

def strip_comment(line):
    out = []
    in_s = in_d = False
    for ch in line:
        if ch == "'" and not in_d:
            in_s = not in_s
        elif ch == '"' and not in_s:
            in_d = not in_d
        elif ch == "#" and not in_s and not in_d:
            break
        out.append(ch)
    return "".join(out)

def unquote(v):
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in ("'", '"'):
        return v[1:-1]
    return v

def flow_literals(path):
    """Literal copy strings a flow asserts or taps. Skips ${...}
    interpolations (environment values, not copy), inline maps, and
    selector properties other than text (ids are not copy)."""
    lits = []
    with open(path, encoding="utf-8", errors="replace") as fh:
        for raw in fh:
            line = strip_comment(raw.rstrip("\n"))
            if not line.strip():
                continue
            for pat in (COMMAND_SCALAR, TEXT_PROP):
                m = pat.match(line)
                if not m:
                    continue
                v = unquote(m.group("v"))
                if not v or "${" in v or v.startswith("{") or ":" in v and " " not in v:
                    continue
                lits.append(norm(v))
                break
    return lits

mobile_dir = os.path.abspath(os.path.join(e2e_dir, "..", ".."))

flows = []
for root, _dirs, names in os.walk(e2e_dir):
    for name in sorted(names):
        if name.endswith(".yaml"):
            flows.append(os.path.join(root, name))
flows.sort()

# literal_norm -> {flow_relpath: arb_key_candidates}
found = {}
total_literals = set()  # every asserted/tapped literal extracted, bound or not
for fpath in flows:
    rel = os.path.relpath(fpath, mobile_dir)
    for lit in flow_literals(fpath):
        total_literals.add((lit, rel))
        keys = exact_values.get(lit)
        if keys:
            found.setdefault((lit, rel), set()).update(keys)

# ---------- manifest load/save ----------

def load_manifest(path):
    bindings = {}  # (key, rel) -> rendered literal or None
    if not os.path.isfile(path):
        return bindings
    with open(path, encoding="utf-8") as fh:
        return parse_manifest(fh.read())

def parse_manifest(content):
    bindings = {}  # (key, rel) -> rendered literal or None
    for line in content.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        key, rel = parts[0].strip(), parts[1].strip()
        rendered = None
        if len(parts) >= 3 and parts[2].startswith("rendered:"):
            rendered = norm(parts[2][len("rendered:"):])
        bindings[(key, rel)] = rendered
    return bindings

# ---------- base-ref ratchet (B2) ----------
# The branch manifest is compared against the base ref's manifest, the same
# pattern as the sibling check_* ratchets (scripts/lib/list_ratchet.sh):
# a binding on the base ref may not vanish from the branch while its ARB key
# and flow file still exist — otherwise UPDATE_BASELINE=1 lets a PR bless its
# own regression. Skipped (bootstrap) until the manifest lands on the base ref.

BASE_REF = os.environ.get("MAESTRO_COPY_DRIFT_BASE_REF", "origin/main")
ALLOW_NO_BASE = os.environ.get("MAESTRO_COPY_DRIFT_ALLOW_NO_BASE", "0") == "1"
MANIFEST_REPO_PATH = "mobile/scripts/baseline/maestro_copy_manifest.txt"
REPO_ROOT = os.path.abspath(os.path.join(e2e_dir, "..", "..", ".."))

def load_base_manifest():
    """(status, bindings): 'ok' | 'bootstrap' (no manifest on base) |
    'unavailable' (base ref unloadable — caller fails closed)."""
    import subprocess

    def git(*args):
        return subprocess.run(["git", "-C", REPO_ROOT, *args],
                              capture_output=True, text=True)

    if git("rev-parse", "--verify", "--quiet", BASE_REF).returncode != 0:
        git("fetch", "--quiet", "--depth=1", "origin", "main")
    if git("rev-parse", "--verify", "--quiet", BASE_REF).returncode != 0:
        return "unavailable", {}
    if git("cat-file", "-e", f"{BASE_REF}:{MANIFEST_REPO_PATH}").returncode != 0:
        return "bootstrap", {}
    raw = git("show", f"{BASE_REF}:{MANIFEST_REPO_PATH}")
    if raw.returncode != 0:
        return "unavailable", {}
    return "ok", parse_manifest(raw.stdout)

def vanished_bindings(old, new):
    """Bindings in `old` but not `new` whose loss is not explained by the ARB
    key or the flow file being gone — i.e. drift erased by regeneration."""
    gone = []
    for key, rel in sorted(set(old) - set(new)):
        if key in all_keys and os.path.isfile(os.path.join(mobile_dir, rel)):
            gone.append((key, rel))
    return gone

HEADER = """# Binding baseline: each English literal the Maestro suite asserts or taps,
# bound to the app_en.arb key it comes from. Generated by
# scripts/check_maestro_copy_drift.sh. Format:
#   <arb_key><TAB><flow path relative to mobile/>[<TAB>rendered:<literal>]
# 'rendered:' rows are hand-maintained bindings for parameterized ARB values
# (ICU placeholders) and survive regeneration; all other rows are auto-derived.
# Regenerate after intentional copy changes with UPDATE_BASELINE=1 and review
# the printed diff — regeneration re-blesses whatever app_en.arb says today.
"""

def save_manifest(path, bindings):
    lines = [HEADER]
    for (key, rel), rendered in sorted(bindings.items()):
        row = f"{key}\t{rel}"
        if rendered is not None:
            row += f"\trendered:{rendered}"
        lines.append(row)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")

# ---------- regenerate ----------

if mode == "regen":
    old = load_manifest(manifest_path)
    new = {}
    for (lit, rel), keys in found.items():
        key = sorted(keys)[0]  # duplicate ARB values bind to the first key
        new[(key, rel)] = None
    # hand-maintained rendered bindings cannot be auto-derived: carry them
    carried = 0
    for (key, rel), rendered in old.items():
        if rendered is not None:
            new[(key, rel)] = rendered
            carried += 1
    added = sorted(set(new) - set(old))
    removed = sorted(set(old) - set(new))
    # B1: regeneration rebuilds bindings only from literals that CURRENTLY
    # match ARB, so on real drift (stale literal, key still in ARB, flow file
    # still present) the binding silently drops out and the guard goes green
    # with the flow still broken. Refuse that unless explicitly accepted.
    blocked = vanished_bindings(old, new)
    if blocked and os.environ.get("ACCEPT_REMOVALS", "0") != "1":
        print("❌ regen refused: these bindings vanish while their ARB key "
              "still exists and the flow file is still present:", file=sys.stderr)
        for key, rel in blocked:
            current = next((v for v, ks in exact_values.items() if key in ks),
                           param_values.get(key, "?"))
            print(f"  - {key}\t{rel}\n      ARB now says: {current}",
                  file=sys.stderr)
        print("A vanished binding is drift being ERASED, not cleanup: the "
              "flow still asserts the old string and the guard would go "
              "permanently green. Update the flow to the current ARB copy "
              "(the binding then re-forms and nothing is removed). If the "
              "flow intentionally stopped asserting that copy, re-run with "
              "ACCEPT_REMOVALS=1 and say so in the PR.", file=sys.stderr)
        sys.exit(1)
    os.makedirs(os.path.dirname(manifest_path), exist_ok=True)
    save_manifest(manifest_path, new)
    print(f"manifest regenerated: {len(new)} bindings "
          f"({len(added)} added, {len(removed)} removed, {carried} hand-maintained)")
    for key, rel in added:
        print(f"  + {key}\t{rel}")
    for key, rel in removed:
        print(f"  - {key}\t{rel}")
    if blocked:
        print(f"WARNING: {len(blocked)} binding(s) removed with "
              "ACCEPT_REMOVALS=1 while their ARB key still exists — the "
              "base-ref ratchet will still fail CI if the base manifest "
              "carries them.")
    if added or removed:
        print("review the diff above: regeneration re-blesses today's ARB copy.")
    sys.exit(0)

# ---------- check ----------

if not os.path.isfile(manifest_path):
    print(f"❌ manifest missing: {manifest_path}", file=sys.stderr)
    print("run UPDATE_BASELINE=1 bash mobile/scripts/check_maestro_copy_drift.sh",
          file=sys.stderr)
    sys.exit(1)

bindings = load_manifest(manifest_path)
failures = 0

for (key, rel), rendered in sorted(bindings.items()):
    fpath = os.path.join(mobile_dir, rel)
    if not os.path.isfile(fpath):
        print(f"❌ DRIFT: bound flow file is missing: {rel} "
              f"(bound to ARB key '{key}')", file=sys.stderr)
        failures += 1
        continue
    with open(fpath, encoding="utf-8", errors="replace") as fh:
        # S4: strip comments like the extractor does — a commented-out
        # assertion must not satisfy its binding.
        text = norm("\n".join(strip_comment(l.rstrip("\n")) for l in fh))

    if key not in all_keys:
        print(f"❌ DRIFT: ARB key '{key}' no longer exists in "
              f"lib/l10n/app_en.arb (bound from {rel}). Re-bind or regenerate.",
              file=sys.stderr)
        failures += 1
        continue

    if rendered is not None:
        if rendered not in text:
            print(f"❌ DRIFT: {rel} no longer contains the rendered string "
                  f"for parameterized ARB key '{key}':\n"
                  f"       expected: {rendered}\n"
                  f"     update the flow, or fix the binding in "
                  f"mobile/scripts/baseline/maestro_copy_manifest.txt",
                  file=sys.stderr)
            failures += 1
        continue

    if key in param_values:
        print(f"❌ DRIFT: ARB key '{key}' (bound from {rel}) now interpolates "
              f"a placeholder: {param_values[key]}\n"
              f"     flows assert the rendered string — add a hand-maintained "
              f"'rendered:' column to this binding in "
              f"mobile/scripts/baseline/maestro_copy_manifest.txt",
              file=sys.stderr)
        failures += 1
        continue

    current = next(v for v, ks in exact_values.items() if key in ks)
    if current not in text:
        print(f"❌ DRIFT: copy changed under the Maestro suite.\n"
              f"       ARB key:  {key}\n"
              f"       flow:     {rel}\n"
              f"       ARB now says: {current}\n"
              f"     That exact string no longer appears in the flow. Update the "
              f"flow to the current copy, or — if the copy change was intentional "
              f"— regenerate: UPDATE_BASELINE=1 bash "
              f"mobile/scripts/check_maestro_copy_drift.sh",
              file=sys.stderr)
        failures += 1

# unregistered literals: exact ARB match with no binding for that file
unregistered = []
for (lit, rel), keys in sorted(found.items()):
    if not any((k, rel) in bindings for k in keys):
        unregistered.append((rel, lit, sorted(keys)))

for rel, lit, keys in unregistered:
    print(f"❌ UNREGISTERED: {rel} asserts ARB-backed copy with no manifest "
          f"binding:\n       \"{lit}\"  (key: {', '.join(keys)})\n"
          f"     Register it: UPDATE_BASELINE=1 bash "
          f"mobile/scripts/check_maestro_copy_drift.sh",
          file=sys.stderr)
    failures += 1

# B2: base-ref ratchet — a binding the base manifest carries may not vanish
# from the branch while its ARB key and flow file still exist. This is what
# makes a regen-erased regression visible in CI even when the branch's own
# check is green. Bootstrap: the manifest does not exist on the base ref until
# this guard merges, so the ratchet is skipped with a note until then.
base_status, base_bindings = load_base_manifest()
if base_status == "ok":
    dropped = vanished_bindings(base_bindings, bindings)
    for key, rel in dropped:
        print(f"❌ ERODED: binding for '{key}' in {rel} exists on {BASE_REF} "
              f"but is gone from this branch's manifest, and the ARB key "
              f"still exists. Regenerating away a drifted binding does not "
              f"fix the drift — update the flow to the current ARB copy.",
              file=sys.stderr)
        failures += 1
elif base_status == "bootstrap":
    print(f"NOTE: no manifest on {BASE_REF} yet (guard not merged); "
          "skipping base-ref ratchet.")
else:
    if ALLOW_NO_BASE:
        print(f"NOTE: {BASE_REF} unavailable; skipping base-ref ratchet "
              "(MAESTRO_COPY_DRIFT_ALLOW_NO_BASE=1, local opt-out).")
    else:
        print(f"❌ could not load the manifest from {BASE_REF}, so the "
              "base-ref ratchet cannot be verified — failing closed. Ensure "
              f"{BASE_REF} is fetched, or set "
              "MAESTRO_COPY_DRIFT_ALLOW_NO_BASE=1 for a local run.",
              file=sys.stderr)
        failures += 1

if failures:
    print("", file=sys.stderr)
    print(f"{failures} copy-drift failure(s). app_en.arb is the source of "
          f"truth: adopt the current ARB copy in the flow, or regenerate the "
          f"manifest for an intentional copy change.", file=sys.stderr)
    sys.exit(1)

# S2: print the denominator — bindings cover only the literals that exactly
# match a non-parameterized ARB value today; the rest (regexes, ids, rendered
# ICU forms, already-drifted copy) are extracted but invisible to the guard.
print(f"✅ Maestro copy-drift guard: {len(bindings)} bindings verified "
      f"(of {len(total_literals)} asserted literals extracted), "
      f"0 unregistered literals.")
PYEOF
