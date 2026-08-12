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
# Runs as a Codemagic build step in every workflow that ships an artifact.
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

case "$base_url" in
  https://*) ;;
  *)
    echo "ERROR: SUPPORTERS_API_BASE_URL must be an absolute https URL." >&2
    echo "  Got: $base_url" >&2
    exit 1
    ;;
esac

# SupporterApiClient normalises the base through _trimBaseUri(), which strips
# trailing slashes and appends exactly one, then resolves each path against it.
# Trailing slashes and path prefixes both survive that correctly:
#
#   https://host      -> https://host/v1/me
#   https://host/     -> https://host/v1/me
#   https://host/api  -> https://host/api/v1/me
#
# A query or fragment does not. _trimBaseUri concatenates the slash onto the
# full string, so 'https://host/api?x=1' becomes 'https://host/api?x=1/' and
# resolving '/v1/me' against it yields 'https://host/v1/me' — the '/api'
# prefix is silently dropped and every request goes to the wrong path.
case "$base_url" in
  *\?* | *\#*)
    echo "ERROR: SUPPORTERS_API_BASE_URL must not contain a query or fragment." >&2
    echo "  SupporterApiClient appends a slash to this value before resolving" >&2
    echo "  each request path. A query or fragment makes that resolution drop" >&2
    echo "  the base path, so requests silently go somewhere else." >&2
    echo "  Got: $base_url" >&2
    echo "  Expected something like: https://supporters.divine.video" >&2
    exit 1
    ;;
esac

echo "Supporter config OK (flag='${flag:-unset}', base='$base_url')."
