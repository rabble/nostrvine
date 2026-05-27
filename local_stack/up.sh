#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"

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

docker compose -f "$COMPOSE_FILE" up -d --wait "${PULL_ARGS[@]}" "${SERVICES[@]}"
docker compose -f "$COMPOSE_FILE" run --rm e2e-seed
