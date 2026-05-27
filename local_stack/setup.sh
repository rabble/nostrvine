#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"

# shellcheck source=android_sdk.sh
source "$SCRIPT_DIR/android_sdk.sh"

# Track whether we actually performed setup work (used to suppress the summary
# on no-op runs, since local_up now runs setup.sh on every invocation).
DID_WORK=false

# ── Prerequisites ────────────────────────────────────────────────────────────

has_errors=false

if ! command -v docker &>/dev/null; then
  echo ""
  echo "  Docker is not installed."
  echo "    macOS:  brew install --cask docker    (then open Docker Desktop)"
  echo "    Linux:  https://docs.docker.com/engine/install/"
  has_errors=true
elif ! docker compose version &>/dev/null; then
  echo ""
  echo "  Docker Compose v2 plugin is not installed."
  echo "    It ships with Docker Desktop. If using Docker Engine on Linux:"
  echo "    https://docs.docker.com/compose/install/linux/"
  has_errors=true
fi

if ! command -v adb &>/dev/null; then
  echo ""
  echo "  adb (Android Debug Bridge) is not installed or not on PATH."
  echo "    If Android Studio is installed, add platform-tools to your PATH:"
  echo "      export PATH=\"\$HOME/Android/Sdk/platform-tools:\$PATH\""
  echo "    Or install standalone:  https://developer.android.com/tools/releases/platform-tools"
  has_errors=true
fi

if ! command -v openssl &>/dev/null; then
  echo ""
  echo "  openssl is not installed."
  echo "    macOS:  pre-installed (or: brew install openssl)"
  echo "    Linux:  sudo apt install openssl  /  sudo pacman -S openssl"
  has_errors=true
fi

if [ "$has_errors" = true ]; then
  echo ""
  echo "Please install the missing tools above and re-run this script."
  exit 1
fi

# ── .env file ────────────────────────────────────────────────────────────────

if [ ! -f "$ENV_FILE" ]; then
  cp "$ENV_EXAMPLE" "$ENV_FILE"
  echo "Created $ENV_FILE from template."
  DID_WORK=true
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

# ── SERVER_NSEC ──────────────────────────────────────────────────────────────

if [ -z "${SERVER_NSEC:-}" ]; then
  nsec="$(openssl rand -hex 32)"
  if grep -q "^SERVER_NSEC=" "$ENV_FILE"; then
    tmp_env="$(mktemp)"
    awk -v nsec="$nsec" '
      /^SERVER_NSEC=/ { print "SERVER_NSEC=" nsec; next }
      { print }
    ' "$ENV_FILE" > "$tmp_env"
    mv "$tmp_env" "$ENV_FILE"
  else
    echo "SERVER_NSEC=$nsec" >> "$ENV_FILE"
  fi
  echo "Generated SERVER_NSEC and wrote to .env"
  DID_WORK=true
fi

# ── Keycast master.key ───────────────────────────────────────────────────────

# Docker creates master.key as a directory when the host path is missing at
# container start (bind-mount race). Detect and remove so the file path is free.
if [ -d "$SCRIPT_DIR/master.key" ]; then
  echo "Removing stray master.key/ directory (Docker bind-mount race)..."
  rmdir "$SCRIPT_DIR/master.key" 2>/dev/null || {
    echo "master.key/ is non-empty — inspect manually before deleting it." >&2
    exit 1
  }
  echo "Next 'mise run local_up' will recreate the keycast container with the file mount."
  DID_WORK=true
fi

if [ ! -f "$SCRIPT_DIR/master.key" ]; then
  echo "Generating keycast master.key..."
  openssl rand 32 | base64 > "$SCRIPT_DIR/master.key"
  echo "master.key generated at $SCRIPT_DIR/master.key"
  DID_WORK=true
fi

# ── Summary ──────────────────────────────────────────────────────────────────

if [ "$DID_WORK" = true ]; then
  echo ""
  echo "Setup complete. Next steps:"
  echo "  cd mobile"
  echo "  mise run local_up       # start all services"
  echo "  mise run local_status   # verify health"
  echo "  mise run local_logs     # inspect startup"
fi
