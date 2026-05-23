#!/usr/bin/env bash
# ABOUTME: Fails CI if production code uses `nsec` as an HTTP payload key.
# ABOUTME: Locks in the Phase 1 fix for divinevideo/divine-mobile#3359.
#
# Background: pre-fix code in `keycast_flutter` set `body['nsec'] = nsec`
# in OAuth registration requests, transmitting the user's Nostr private
# key over the wire. The fix removes that surface entirely. This guard
# fires if a future change re-introduces the same shape (or a moral
# equivalent like `'nsec':` / `"nsec":` in a map literal) anywhere in
# production code.
#
# Legitimate uses NOT flagged:
# - `nsec:` as a Dart named parameter (no quotes).
# - `'nsec'` in test assertions like `containsKey('nsec')` (no colon
#   immediately after the closing quote).
# - Comments and doc strings.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_ROOT"

# Search roots: production code only.
ROOTS=(
  "mobile/lib"
  "mobile/packages"
)

# Patterns that uniquely indicate `nsec` is being used as a payload key.
PATTERN="(body\[['\"]nsec['\"]\])|(['\"]nsec['\"][[:space:]]*:)"

# File suffixes / paths to exclude.
EXCLUDES=(
  "_test.dart"
  ".g.dart"
  ".freezed.dart"
  ".mocks.dart"
  "/l10n/generated/"
)

tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT

# Find dart files, run grep, exclude generated/test files in post-filter.
find "${ROOTS[@]}" -type f -name "*.dart" 2>/dev/null \
  | while IFS= read -r f; do
      skip=0
      for ex in "${EXCLUDES[@]}"; do
        case "$f" in *"$ex"*) skip=1; break;; esac
      done
      [ "$skip" -eq 1 ] && continue
      grep -nE "$PATTERN" "$f" 2>/dev/null \
        | sed "s|^|$f:|" \
        || true
    done > "$tmpfile"

if [ -s "$tmpfile" ]; then
  cat "$tmpfile"
  echo
  echo "❌ One or more files use 'nsec' as a payload key in production code."
  echo "   This pattern is banned by the Phase 1 fix for"
  echo "   divinevideo/divine-mobile#3359 (BYOK nsec leak prevention)."
  echo
  echo "   If you are intentionally re-introducing BYOK identity binding,"
  echo "   use the proof-of-possession contract from divinevideo/keycast#197"
  echo "   (byok_pubkey + byok_proof) instead of forwarding the nsec."
  exit 1
fi

echo "✅ No nsec-as-payload-key usages detected in production code."
