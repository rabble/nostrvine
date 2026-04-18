#!/usr/bin/env bash
set -euo pipefail

package_shim="packages/hls_auth_web_player/web/hls_auth_web_player.js"
app_shim="web/hls_auth_web_player.js"

if ! cmp -s "$package_shim" "$app_shim"; then
  echo "HLS auth web shims are out of sync:"
  echo "  $package_shim"
  echo "  $app_shim"
  echo
  echo "Update the package shim first, then copy it to the app web directory."
  diff -u "$package_shim" "$app_shim" || true
  exit 1
fi
