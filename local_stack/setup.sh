#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"

# ── Prerequisites ────────────────────────────────────────────────────────────

echo "Checking prerequisites..."

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

echo "All prerequisites found."

# ── .env file ────────────────────────────────────────────────────────────────

if [ ! -f "$ENV_FILE" ]; then
  cp "$ENV_EXAMPLE" "$ENV_FILE"
  echo "Created $ENV_FILE from template."
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

# ── SERVER_NSEC ──────────────────────────────────────────────────────────────

if [ -z "${SERVER_NSEC:-}" ]; then
  nsec="$(openssl rand -hex 32)"
  if grep -q "^SERVER_NSEC=" "$ENV_FILE"; then
    sed -i "s/^SERVER_NSEC=.*/SERVER_NSEC=$nsec/" "$ENV_FILE"
  else
    echo "SERVER_NSEC=$nsec" >> "$ENV_FILE"
  fi
  echo "Generated SERVER_NSEC and wrote to .env"
fi

# ── Keycast master.key ───────────────────────────────────────────────────────

if [ ! -f "$SCRIPT_DIR/master.key" ]; then
  echo "Generating keycast master.key..."
  openssl rand 32 | base64 > "$SCRIPT_DIR/master.key"
  echo "master.key generated at $SCRIPT_DIR/master.key"
else
  echo "master.key already exists."
fi

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "Setup complete. Next steps:"
echo "  cd mobile"
echo "  mise run local_up       # start all services"
echo "  mise run local_status   # verify health"
echo "  mise run local_logs     # inspect startup"
