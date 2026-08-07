#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"

# shellcheck source=preflight.sh
source "${SCRIPT_DIR}/preflight.sh"

PULL_ARGS=()
case "${1:-}" in
  --pull=missing)
    PULL_ARGS+=(--pull=missing)
    ;;
  "")
    ;;
  *)
    echo "Unknown argument: $1" >&2
    echo "Usage: $0 [--pull=missing]" >&2
    exit 2
    ;;
esac

SERVICES=(
  keycast keycast-postgres keycast-redis
  funnelcake-relay funnelcake-api funnelcake-proxy funnelcake-redis funnelcake-clickhouse
  minio blossom blossom-proxy invite
)

# SERVICES plus the one-shot jobs compose pulls in as dependencies. Failures
# often land in those, so the post-mortem has to be able to see them.
REPORT_SERVICES=(
  "${SERVICES[@]}"
  keycast-migrate funnelcake-migrate funnelcake-local-tuning minio-init
)

# Fail early and by name on port clashes, instead of letting the daemon report
# an anonymous "port is already allocated" partway through startup.
if ! preflight_ports "$COMPOSE_FILE"; then
  exit 1
fi

# Advisory only — a stale mirror still starts, it just cannot serve NIP-17.
preflight_image_staleness "$SCRIPT_DIR"

UP_CMD=(docker compose -f "$COMPOSE_FILE" up -d --wait)
if ((${#PULL_ARGS[@]} > 0)); then
  UP_CMD+=("${PULL_ARGS[@]}")
fi
UP_CMD+=("${SERVICES[@]}")

UP_LOG="$(mktemp)"
SEED_LOG="$(mktemp)"
trap 'rm -f "$UP_LOG" "$SEED_LOG"' EXIT

# Containers occasionally start before Docker's embedded DNS knows their
# dependency's alias ("no such host" / "Temporary failure in name resolution").
# `up` is idempotent and restarts whatever died, so a bounded retry clears it.
MAX_ATTEMPTS=3
RETRY_DELAY=5

attempt=1
while true; do
  set +e
  "${UP_CMD[@]}" 2>&1 | tee "$UP_LOG"
  UP_RC="${PIPESTATUS[0]}"
  set -e

  if [[ "$UP_RC" -eq 0 ]]; then
    break
  fi

  if ((attempt < MAX_ATTEMPTS)) &&
    stack_failure_is_transient "$COMPOSE_FILE" "$UP_LOG" "${REPORT_SERVICES[@]}"; then
    echo "" >&2
    echo "Name resolution failed during startup — a known race. Retrying in ${RETRY_DELAY}s (attempt $((attempt + 1)) of ${MAX_ATTEMPTS})." >&2
    echo "" >&2
    sleep "$RETRY_DELAY"
    attempt=$((attempt + 1))
    continue
  fi

  stack_failure_report "$COMPOSE_FILE" "$SCRIPT_DIR" "${REPORT_SERVICES[@]}"
  exit "$UP_RC"
done

# Snapshot read models rebuild on production cadences (5-30 minutes), which
# makes a freshly published video invisible to the REST API for far longer than
# any test waits. Shorten the intervals the app and the e2e actually read.
# Every statement is optional — none of these views exist on the pinned schema.
set +e
docker compose -f "$COMPOSE_FILE" run --rm funnelcake-local-tuning
set -e

# Report the applied schema version. The pre-flight check can only say the image
# is old; this names the actual gap, and it is the first thing to look at when a
# relay behaviour does not match production.
SCHEMA_VERSION="$(docker compose -f "$COMPOSE_FILE" exec -T funnelcake-clickhouse \
  clickhouse-client --password clickhouse --query \
  "SELECT max(version) FROM nostr.schema_migrations" 2>/dev/null | tr -d '[:space:]')"
if [[ -n "$SCHEMA_VERSION" ]]; then
  echo "funnelcake schema version: ${SCHEMA_VERSION}"
fi

# `--rm` takes the seed container away with it, so its logs are gone by the
# time a post-mortem could ask for them. Keep a copy.
set +e
docker compose -f "$COMPOSE_FILE" run --rm e2e-seed 2>&1 | tee "$SEED_LOG"
SEED_RC="${PIPESTATUS[0]}"
set -e

if [[ "$SEED_RC" -ne 0 ]]; then
  {
    echo ""
    echo "=== e2e-seed failed ==="
    echo ""
    echo "The services themselves may still be healthy — the seed only loads"
    echo "relay/blossom fixtures."
    echo ""
    echo "--- last 20 log lines: e2e-seed ---"
    tail -n 20 "$SEED_LOG" | sed 's/^/    /'
    echo ""
  } >&2
  stack_service_status "$COMPOSE_FILE" "${REPORT_SERVICES[@]}"
  stack_bypass_hint "$SCRIPT_DIR" \
    "Only tests that read seeded relay/blossom data need it."
  exit "$SEED_RC"
fi
