#!/usr/bin/env bash
# Fails when the account-deletion coordinator route is absent or unreachable.
# HTTP 401 passes: it proves the unauthenticated request reached a mounted route.
# HTTP 404 fails: it means the client would ship ahead of its required backend.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$MOBILE_ROOT"

if [ -n "${DEFAULT_ENV:-}" ]; then
  dart run scripts/lib/coordinator_route_probe.dart "--environment=$DEFAULT_ENV"
else
  dart run scripts/lib/coordinator_route_probe.dart
fi
