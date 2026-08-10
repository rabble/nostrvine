#!/usr/bin/env bash
# Fails a build whose supporter subscription configuration is incoherent.
#
# Two variables drive the feature:
#
#   FF_DIVINE_SUPPORTERS   - master switch, read by bool.fromEnvironment
#   SUPPORTERS_API_BASE_URL - base URL of the divine-supporters Worker
#
# The build steps interpolate both unconditionally, so an unset variable emits
# `--dart-define=NAME=` — a define that is present but empty, which overrides
# the Dart-side default rather than falling back to it. For these two that
# happens to fail safe (empty URL means supporterApiClientProvider returns
# null, empty flag is false), but it fails *silently*: you get a build where
# the supporter screen appears and can never reach the server, and nothing
# says so until a purchase 500s in someone's hands.
#
# So the invariant enforced here is not "both must be set" — it is "these two
# must agree". A flag turned on without a server is the broken combination.
#
# Portable: POSIX sh constructs + grep -E only, so it runs on CI ubuntu and on
# the macOS pre-push hook.
set -euo pipefail

flag="${FF_DIVINE_SUPPORTERS:-}"
base_url="${SUPPORTERS_API_BASE_URL:-}"

# The flag, when set at all, must be something bool.fromEnvironment understands.
# Anything else silently evaluates to false, which looks like the feature was
# never enabled rather than like a typo.
if [ -n "$flag" ] && [ "$flag" != "true" ] && [ "$flag" != "false" ]; then
  echo "ERROR: FF_DIVINE_SUPPORTERS is '$flag'." >&2
  echo "  bool.fromEnvironment only recognises 'true' or 'false'. Any other" >&2
  echo "  value evaluates to false, so the feature would stay off and look" >&2
  echo "  like it was never enabled." >&2
  exit 1
fi

# A flag with no server is the combination that ships broken.
if [ "$flag" = "true" ] && [ -z "$base_url" ]; then
  echo "ERROR: FF_DIVINE_SUPPORTERS=true but SUPPORTERS_API_BASE_URL is empty." >&2
  echo "  supporterApiClientProvider returns null when the URL is empty, so the" >&2
  echo "  supporter screen would render with no way to claim a purchase or read" >&2
  echo "  entitlement. Set SUPPORTERS_API_BASE_URL in the Codemagic" >&2
  echo "  'supporters_credentials' environment variable group, or turn the flag" >&2
  echo "  off for this build." >&2
  exit 1
fi

# An unset URL is fine on its own: the feature is inert.
if [ -z "$base_url" ]; then
  exit 0
fi

# SupporterApiClient does `_baseUri.resolve(path)`, which discards anything
# after the last slash of the base. A base with a trailing slash or a path
# segment therefore silently rewrites every request URL.
case "$base_url" in
  https://*) ;;
  *)
    echo "ERROR: SUPPORTERS_API_BASE_URL must be an absolute https URL." >&2
    echo "  Got: $base_url" >&2
    exit 1
    ;;
esac

case "$base_url" in
  */)
    echo "ERROR: SUPPORTERS_API_BASE_URL must not end in a slash." >&2
    echo "  SupporterApiClient calls Uri.resolve(), which drops everything after" >&2
    echo "  the final slash, so a trailing slash changes where requests go." >&2
    echo "  Got: $base_url" >&2
    exit 1
    ;;
esac

# Origin only — no path. Same Uri.resolve() reason as above.
if printf '%s' "$base_url" | grep -Eq '^https://[^/]+/.+'; then
  echo "ERROR: SUPPORTERS_API_BASE_URL must be an origin with no path." >&2
  echo "  SupporterApiClient resolves '/v1/...' against this value, so a path" >&2
  echo "  segment here is discarded and requests silently go elsewhere." >&2
  echo "  Got: $base_url" >&2
  echo "  Expected something like: https://supporters.divine.video" >&2
  exit 1
fi

echo "Supporter config OK (flag='${flag:-unset}', base='$base_url')."
