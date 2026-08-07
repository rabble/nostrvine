#!/usr/bin/env bash
# Build the three funnelcake images from a local divine-funnelcake checkout.
#
# WHY THIS EXISTS
#
# local_stack pins ghcr.io/divinevideo/funnelcake-{migrate,relay,api}:latest.
# Those tags are frozen at 2026-02-24 because divine-funnelcake's CI push to
# GHCR has failed with `denied: permission_denied: write_package` on every run
# since the step was added (2026-03-07), and `continue-on-error: true` makes the
# GitHub jobs API report the failing step as a success. Nothing there is fixable
# from divine-mobile — see divine-mobile#6594.
#
# The consequence is a relay whose `nostr.allowed_kinds` stops at migration 70,
# so kind 1059 (NIP-59 gift wrap) and kind 10050 (NIP-17 DM relay list) are
# rejected outright and NIP-17 cannot be exercised locally at all.
#
# This script builds the images the way divine-funnelcake's own CI does, using
# divine-funnelcake's own Dockerfiles. It deliberately duplicates none of that
# build logic.
#
# WHY IT IS A SCRIPT AND NOT A COMPOSE `build:` STANZA
#
# Only `database/Dockerfile` (migrate) carries a runtime stage. The root
# Dockerfile ends at `FROM scratch AS binaries`; the relay and api runtime
# stages live in `Dockerfile.prebuilt`, which COPYs from a host `binaries/`
# directory that exists only after the `binaries` stage has been exported. That
# is two builds with two contexts, which a compose `build:` (one Dockerfile, one
# context per service) cannot express.
#
# ALL THREE OR NONE
#
# Do not build only migrate. A schema-200 database under the frozen 2026-02-24
# api binary makes `GET /api/users/{pubkey}/videos` return HTTP 500
# ("query failed: string is not valid utf8"), because the ClickHouse column
# types moved under a binary that did not. Measured on 2026-08-07.
#
# USAGE
#
#   bash local_stack/build_funnelcake.sh
#   # add the printed override lines to local_stack/.env
#   mise run local_reset
#
# Point at a checkout elsewhere by setting DIVINE_FUNNELCAKE_ROOT in
# local_stack/.env or in the shell before invoking this script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$ENV_FILE"
fi

FUNNELCAKE_ROOT="${DIVINE_FUNNELCAKE_ROOT:-${SCRIPT_DIR}/../../divine-funnelcake}"
TAG="${FUNNELCAKE_LOCAL_TAG:-local}"

EXPORT_ONLY=0
case "${1:-}" in
  --export-only) EXPORT_ONLY=1 ;;
  "") ;;
  *)
    echo "Unknown argument: $1" >&2
    echo "Usage: $0 [--export-only]" >&2
    exit 2
    ;;
esac

print_exports() {
  echo "export FUNNELCAKE_MIGRATE_IMAGE=funnelcake-migrate:${TAG}"
  echo "export FUNNELCAKE_RELAY_IMAGE=funnelcake-relay:${TAG}"
  echo "export FUNNELCAKE_API_IMAGE=funnelcake-api:${TAG}"
  # The locally built images are not in any registry, so `pull_policy: always`
  # would fail the pull before the local image is ever considered.
  echo "export FUNNELCAKE_PULL_POLICY=never"
}

if [[ "$EXPORT_ONLY" -eq 1 ]]; then
  print_exports
  exit 0
fi

if [[ ! -d "$FUNNELCAKE_ROOT/.git" ]]; then
  {
    echo "divine-funnelcake checkout not found at:"
    echo "    $FUNNELCAKE_ROOT"
    echo ""
    echo "Clone it next to divine-mobile (the repo is private, so this needs"
    echo "GitHub access to the divinevideo org):"
    echo ""
    echo "    gh repo clone divinevideo/divine-funnelcake \"$FUNNELCAKE_ROOT\""
    echo ""
    echo "Or point at an existing checkout:"
    echo ""
    echo "    DIVINE_FUNNELCAKE_ROOT=/path/to/divine-funnelcake $0"
    echo ""
    echo "Or set DIVINE_FUNNELCAKE_ROOT in ${ENV_FILE}."
  } >&2
  exit 1
fi

FUNNELCAKE_ROOT="$(cd "$FUNNELCAKE_ROOT" && pwd)"
BUILD_REF="$(git -C "$FUNNELCAKE_ROOT" rev-parse --short HEAD)"
echo "Building funnelcake images from ${FUNNELCAKE_ROOT} @ ${BUILD_REF}"
echo ""

# `binaries` is a `FROM scratch` stage, so it exports as a plain directory.
BINARIES_DIR="$(mktemp -d)"
trap 'rm -rf "$BINARIES_DIR"' EXIT

echo "==> cake + funnel (release binaries)"
docker build \
  --target binaries \
  --build-arg CARGO_BIN_ARGS="--bin cake --bin funnel" \
  --build-arg RELEASE_BINARIES="cake funnel" \
  -o "type=local,dest=${BINARIES_DIR}" \
  "$FUNNELCAKE_ROOT"

# Dockerfile.prebuilt COPYs `binaries/<name>`, so the exported binaries have to
# sit under that directory name inside the build context.
PREBUILT_CTX="$(mktemp -d)"
trap 'rm -rf "$BINARIES_DIR" "$PREBUILT_CTX"' EXIT
mkdir -p "${PREBUILT_CTX}/binaries"
cp "${BINARIES_DIR}/cake" "${BINARIES_DIR}/funnel" "${PREBUILT_CTX}/binaries/"
cp "${FUNNELCAKE_ROOT}/Dockerfile.prebuilt" "${PREBUILT_CTX}/"

echo "==> funnelcake-relay:${TAG}"
docker build -f "${PREBUILT_CTX}/Dockerfile.prebuilt" --target relay \
  -t "funnelcake-relay:${TAG}" "$PREBUILT_CTX"

echo "==> funnelcake-api:${TAG}"
docker build -f "${PREBUILT_CTX}/Dockerfile.prebuilt" --target api \
  -t "funnelcake-api:${TAG}" "$PREBUILT_CTX"

echo "==> funnelcake-migrate:${TAG}"
docker build -f "${FUNNELCAKE_ROOT}/database/Dockerfile" \
  -t "funnelcake-migrate:${TAG}" "$FUNNELCAKE_ROOT"

echo ""
echo "Built funnelcake-{migrate,relay,api}:${TAG} from ${BUILD_REF}."
echo ""
echo "Point local_stack at them by adding this to local_stack/.env, which every"
echo "docker compose invocation reads automatically:"
echo ""
print_exports | sed 's/^export /    /'
echo ""
echo "Prefer .env over exporting in one shell. The variables have to apply to"
echo "EVERY compose command: a plain \`docker compose run ...\` in a terminal that"
echo "lacks them picks the pinned golang-migrate image back up, runs it against a"
echo "database the Rust migrator owns, and wedges it with"
echo "\"Dirty database version N\" — recoverable only by wiping the volume."
echo ""
echo "Then reset, because the schema jumps from 70 to current:"
echo ""
echo "    mise run local_reset"
