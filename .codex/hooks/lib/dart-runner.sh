#!/bin/bash

# Shared Dart toolchain resolution for repository Codex hooks.

resolve_dart_runner() {
  DART_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
  DART_MOBILE_DIR="$DART_REPO_ROOT/mobile"
  DART_RUNNER=""
  DART_RESOLUTION_REASON=""

  if command -v mise >/dev/null 2>&1 && [ -f "$DART_MOBILE_DIR/mise.toml" ]; then
    if (cd "$DART_MOBILE_DIR" && mise exec -- dart --version >/dev/null 2>&1); then
      DART_RUNNER="mise"
      return 0
    fi
    DART_RESOLUTION_REASON="mise could not load mobile/mise.toml. Review it, run 'cd mobile && mise trust', and retry."
  fi

  if command -v dart >/dev/null 2>&1; then
    DART_RUNNER="dart"
    return 0
  fi

  if [ -z "$DART_RESOLUTION_REASON" ]; then
    DART_RESOLUTION_REASON="No Dart SDK was found. Install mise and run 'cd mobile && mise install'."
  fi
  return 1
}

run_repo_dart() {
  local working_directory="$1"
  shift

  case "$DART_RUNNER" in
    mise)
      (cd "$working_directory" && mise exec -- dart "$@")
      ;;
    dart)
      (cd "$working_directory" && dart "$@")
      ;;
    *)
      return 127
      ;;
  esac
}
