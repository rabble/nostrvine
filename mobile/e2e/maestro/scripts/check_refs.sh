#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# Verify every `runFlow:` reference in the Maestro suite resolves.
#
# Case matters: macOS defaults to a case-insensitive filesystem, so a
# reference like ../tests/unFollow.yaml resolves locally against
# tests/unfollow.yaml and then hard-fails on the linux_x2 runner that
# executes e2e-smoke-android. This check is case-sensitive on every
# platform.
#
#   bash mobile/e2e/maestro/scripts/check_refs.sh
# ------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAESTRO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

failures=0

while IFS= read -r yaml; do
  # Strip comments so commented-out runFlow lines are not treated as live.
  while IFS= read -r ref; do
    [[ -n "${ref}" ]] || continue
    resolved="$(cd "$(dirname "${yaml}")" && printf '%s' "$(pwd)/${ref}")"
    dir="$(dirname "${resolved}")"
    base="$(basename "${resolved}")"

    if [[ ! -d "${dir}" ]]; then
      echo "❌ ${yaml#"${MAESTRO_DIR}/"}: directory missing for '${ref}'" >&2
      failures=$((failures + 1))
      continue
    fi

    # Case-sensitive existence check: compare against the real directory
    # listing rather than trusting the filesystem's own matching.
    if ! ls -1 "${dir}" | grep -Fxq "${base}"; then
      echo "❌ ${yaml#"${MAESTRO_DIR}/"}: unresolved reference '${ref}'" >&2
      failures=$((failures + 1))
    fi
  done < <(sed 's/#.*//' "${yaml}" | grep -oE '\.\./[A-Za-z0-9_/&.-]+\.yaml' || true)
done < <(find "${MAESTRO_DIR}" -name '*.yaml' -type f)

if [[ "${failures}" -gt 0 ]]; then
  echo "" >&2
  echo "${failures} unresolved Maestro flow reference(s)." >&2
  exit 1
fi

echo "✅ All Maestro flow references resolve (case-sensitive)."
