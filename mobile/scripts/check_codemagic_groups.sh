#!/usr/bin/env bash
# Fails CI when codemagic.yaml references an environment variable group that
# the setup checklist at the top of that file does not document.
#
# Why this exists: Codemagic validates the whole codemagic.yaml *before* it
# provisions a machine, so a `groups:` entry naming a group that does not exist
# in the project kills every workflow in the file immediately — not just the one
# that needs it, and not just the feature it belongs to. No in-script guard can
# catch it, because no script ever runs.
#
# That has happened twice:
#   - `supporters_credentials` (#6999) took down iOS, Android, macOS and both
#     E2E lanes for two days (#7203), while the guard added alongside it
#     (check_supporters_config.sh) could never fire.
#   - `maestro_e2e_credentials` has blocked both E2E workflows since they were
#     written, with the same unreachable in-script guard.
#
# Both had one signature: a `groups:` entry added with no corresponding entry in
# the file's own setup checklist. Nothing offline can prove a group exists in
# the Codemagic project, but requiring it to be *documented* forces the author
# to confront the setup step, which is where both omissions happened. When
# CODEMAGIC_API_TOKEN and CODEMAGIC_APP_ID are present the check goes further
# and verifies existence against the API.
#
# Two-way invariant, matching check_backend_host_defaults.sh:
#   1. Referenced but undocumented -> FAIL (catches a new group added without
#      its setup step, which is the outage above).
#   2. Documented but unreferenced -> FAIL (stops the checklist ossifying with
#      entries for groups nothing uses any more).
#
# Portable: POSIX sh constructs + grep -E / sed only, so it runs on both CI
# ubuntu and the macOS pre-push hook.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Scripts run with working-directory mobile/; codemagic.yaml is at the repo root.
YAML="${CODEMAGIC_YAML:-$SCRIPT_DIR/../../codemagic.yaml}"

if [ ! -f "$YAML" ]; then
  echo "check_codemagic_groups: cannot find codemagic.yaml at $YAML" >&2
  exit 1
fi

# The setup checklist is the comment block above `definitions:`. Restricting to
# it keeps an incidental mention further down the file from counting as
# documentation.
header="$(sed -n '1,/^definitions:/p' "$YAML")"

# Documented groups: any quoted name in the header. Both phrasings the file
# already uses are covered —
#   `Create environment variable group "zendesk_credentials" with:`
#   `Requires GITHUB_TOKEN in "github_credentials" environment variable group`
documented="$(printf '%s\n' "$header" \
  | grep -oE '"[a-z0-9_]+"' \
  | tr -d '"' \
  | grep -E '_credentials$|^firebase$|^google_play' \
  | sort -u || true)"

# Referenced groups: list items inside a `groups:` block. `groups:` is the only
# bare-list-of-identifiers key in the environment stanza, so anchoring on it
# avoids picking up `scripts:` anchors or artifact globs.
#
# Comments and blank lines inside the block must NOT end it: treating them as
# terminators silently drops every entry after them, which is precisely the
# false negative this guard exists to prevent.
referenced="$(awk '
  /^[[:space:]]*groups:[[:space:]]*$/ { in_groups = 1; next }
  in_groups && /^[[:space:]]*(#|$)/ { next }
  in_groups && /^[[:space:]]*-[[:space:]]+[a-z0-9_]+[[:space:]]*$/ {
    gsub(/^[[:space:]]*-[[:space:]]+|[[:space:]]*$/, ""); print; next
  }
  { in_groups = 0 }
' "$YAML" | sort -u)"

fail=0

undocumented="$(comm -23 <(printf '%s\n' "$referenced") <(printf '%s\n' "$documented"))"
if [ -n "$undocumented" ]; then
  fail=1
  echo "FAIL: codemagic.yaml references environment variable group(s) that its" >&2
  echo "      setup checklist does not document:" >&2
  printf '        - %s\n' $undocumented >&2
  echo "" >&2
  echo "      Codemagic rejects the entire config when a named group does not" >&2
  echo "      exist, so every workflow in the file fails before any step runs." >&2
  echo "      Create the group in the Codemagic project, then document it in the" >&2
  echo "      numbered setup checklist at the top of codemagic.yaml." >&2
fi

stale="$(comm -13 <(printf '%s\n' "$referenced") <(printf '%s\n' "$documented"))"
if [ -n "$stale" ]; then
  fail=1
  echo "FAIL: the codemagic.yaml setup checklist documents group(s) that no" >&2
  echo "      workflow references any more:" >&2
  printf '        - %s\n' $stale >&2
  echo "" >&2
  echo "      Remove the checklist entry so the setup instructions stay true." >&2
fi

# Optional API cross-check — ADVISORY ONLY, never fails the build.
#
# `GET /apps/{id}` enumerates app-level variables but NOT team-level shared
# groups. `github_credentials` is the proof: it is absent from that payload, yet
# ios-build and android-build reference it and succeed, which is impossible for
# a group Codemagic considers unknown. Failing on this list would therefore red
# every PR over a group that is present.
#
# The only authoritative existence test is starting a build and reading the
# validation error, which is far too expensive to run per-PR. So this layer
# reports a suspicion and leaves the verdict to the documentation invariant.
if [ -n "${CODEMAGIC_API_TOKEN:-}" ] && [ -n "${CODEMAGIC_APP_ID:-}" ]; then
  app_level="$(curl -sS -H "x-auth-token: $CODEMAGIC_API_TOKEN" \
    "https://api.codemagic.io/apps/$CODEMAGIC_APP_ID" 2>/dev/null \
    | tr ',{}[]' '\n' | grep -oE '"group"[[:space:]]*:[[:space:]]*"[a-z0-9_]+"' \
    | sed -E 's/.*"([a-z0-9_]+)"$/\1/' | sort -u || true)"
  if [ -z "$app_level" ]; then
    echo "note: could not read group names from the Codemagic API; skipping the"
    echo "      advisory cross-check."
  else
    unseen="$(comm -23 <(printf '%s\n' "$referenced") <(printf '%s\n' "$app_level"))"
    if [ -n "$unseen" ]; then
      echo "note: referenced group(s) not visible in the app-level Codemagic API"
      echo "      response. This is NOT proof they are missing — team-level shared"
      echo "      groups never appear here — but it is where to look first if a"
      echo "      build fails with 'unknown variable group':"
      printf '        - %s\n' $unseen
    fi
  fi
else
  echo "check_codemagic_groups: no Codemagic credentials in env — documentation check only"
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "check_codemagic_groups: OK — $(printf '%s\n' "$referenced" | grep -c .) referenced group(s), all documented"
