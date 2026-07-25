#!/usr/bin/env bash
# Frames raw captures into marketing images (brand canvas + caption +
# rounded screenshot) via frame_screenshots.py. Bootstraps a local venv with
# Pillow on first run so there is no manual pip step. Run from mobile/ios.
set -euo pipefail

cd "$(dirname "$0")"                 # mobile/ios/fastlane
VENV=".venv"

if [ ! -x "$VENV/bin/python" ]; then
  echo "🖼️  Setting up framing venv (first run)…"
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet --upgrade pip
  "$VENV/bin/pip" install --quiet Pillow
fi

"$VENV/bin/python" frame_screenshots.py screenshots
echo "✅ Framed marketing images written to fastlane/screenshots/<locale>/*_framed.png"
