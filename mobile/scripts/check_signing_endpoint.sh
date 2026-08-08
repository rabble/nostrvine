#!/usr/bin/env bash
# Fails a build whose PROOFMODE_SIGNING_SERVER_ENDPOINT is malformed.
#
# The signer appends "?platform=ios" / "?platform=android" to this value, so an
# endpoint that stops at the host collapses to the service root. A service root
# answers HTTP 200 with an HTML landing page, and the C2PA signer then reports a
# bare "Signature: internal error" during capture — indistinguishable from a
# server outage, and it sends users to debug their own connection.
#
# An UNSET variable is not an error by default: the app falls back to the
# default endpoint in C2paSigningService.defaultSigningServerEndpoint. Only a
# value that is set and wrong fails here, plus the literal "disabled", which
# turns signing off for CI and unconfigured builds.
#
# Set REQUIRE_SIGNING_ENDPOINT=1 to also reject an unset/empty value. Codemagic
# needs this: it interpolates the variable unconditionally, so an unset variable
# emits `--dart-define=PROOFMODE_SIGNING_SERVER_ENDPOINT=` — a define that is
# present but empty, which overrides the Dart-side defaultValue rather than
# falling back to it.
#
# Portable: POSIX sh constructs + grep -E only, so it runs on CI ubuntu and on
# the macOS pre-push hook.
set -euo pipefail

REQUIRED_PATH="/api/v1/c2pa/configuration"
DISABLED_SENTINEL="disabled"

endpoint="${PROOFMODE_SIGNING_SERVER_ENDPOINT:-}"

# Unset: the Dart default applies, unless this build injects the value
# unconditionally and would therefore ship an empty define.
if [ -z "$endpoint" ]; then
  if [ "${REQUIRE_SIGNING_ENDPOINT:-0}" = "1" ]; then
    echo "ERROR: PROOFMODE_SIGNING_SERVER_ENDPOINT is unset or empty." >&2
    echo "  This build injects the value unconditionally, so an unset variable" >&2
    echo "  ships --dart-define=PROOFMODE_SIGNING_SERVER_ENDPOINT= (present but" >&2
    echo "  empty), which overrides the in-app default instead of falling back" >&2
    echo "  to it. C2PA signing would then fail on every capture." >&2
    echo >&2
    echo "  Set it in the Codemagic 'proofmode_credentials' environment variable" >&2
    echo "  group to an absolute https URL ending in $REQUIRED_PATH," >&2
    echo "  or to 'disabled' to build without C2PA signing." >&2
    exit 1
  fi
  exit 0
fi

# Explicitly disabled: signing is off for this build, by design.
if [ "$(printf '%s' "$endpoint" | tr '[:upper:]' '[:lower:]')" = "$DISABLED_SENTINEL" ]; then
  exit 0
fi

fail() {
  echo "ERROR: PROOFMODE_SIGNING_SERVER_ENDPOINT is malformed." >&2
  echo "  $1" >&2
  echo >&2
  echo "  Expected an absolute https URL ending in $REQUIRED_PATH," >&2
  echo "  for example: https://proofsign.divine.video$REQUIRED_PATH" >&2
  echo >&2
  echo "  Set it in the Codemagic 'proofmode_credentials' environment variable" >&2
  echo "  group, or unset it to use the in-app default. Use 'disabled' to build" >&2
  echo "  without C2PA signing." >&2
  exit 1
}

case "$endpoint" in
  https://*) ;;
  *) fail "It must use https. Got: $endpoint" ;;
esac

case "$endpoint" in
  *\?*) fail "It must not carry a query string; the platform parameter is appended at call time. Got: $endpoint" ;;
esac

case "$endpoint" in
  *"$REQUIRED_PATH") ;;
  *) fail "It must end in $REQUIRED_PATH. A bare host resolves to the service root, which returns an HTML landing page instead of a signing configuration. Got: $endpoint" ;;
esac

echo "PROOFMODE_SIGNING_SERVER_ENDPOINT looks well-formed."
