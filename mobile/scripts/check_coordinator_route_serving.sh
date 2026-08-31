#!/usr/bin/env bash
# Fails unless the account-deletion coordinator route rejects a credential-free
# GET with HTTP 401. Missing, unreachable, unavailable, and unexpected responses
# mean the client would ship without its required backend contract.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$MOBILE_ROOT"

if [ -n "${DEFAULT_ENV:-}" ]; then
  dart run scripts/lib/coordinator_route_probe.dart "--environment=$DEFAULT_ENV"
else
  dart run scripts/lib/coordinator_route_probe.dart
fi
