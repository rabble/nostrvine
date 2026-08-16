#!/bin/bash
# Hook: PostToolUse (Edit|Write)
# Format edited Dart files, then require zero analyzer diagnostics.

set -e

HOOK_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/dart-runner.sh
# shellcheck disable=SC1091
source "$HOOK_DIR/lib/dart-runner.sh"

emit_block() {
  jq -n --arg reason "$1" '{decision: "block", reason: $reason}'
  exit 0
}

emit_system_message() {
  jq -n --arg message "$1" '{systemMessage: $message}'
  exit 0
}

INPUT=$(cat)
PATCH=$(printf '%s\n' "$INPUT" | jq -r '.tool_input.command // empty')
FILES=$(printf '%s\n' "$PATCH" | sed -nE \
  -e 's/^\*\*\* (Add|Update) File: (.*)$/\2/p' \
  -e 's/^\*\*\* Move to: (.*)$/\1/p')

[ -n "$FILES" ] || exit 0

DART_READY=false

while IFS= read -r FILE_PATH; do
  [[ "$FILE_PATH" =~ \.dart$ ]] || continue
  [ -f "$FILE_PATH" ] || continue

  FILE_DIR=$(dirname "$FILE_PATH")
  CANONICAL_FILE_PATH="$FILE_PATH"
  if CANONICAL_FILE_DIR=$(cd -P "$FILE_DIR" 2>/dev/null && pwd); then
    CANONICAL_FILE_PATH="$CANONICAL_FILE_DIR/$(basename "$FILE_PATH")"
  fi
  REPO_ROOT=$(git -C "$FILE_DIR" rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$REPO_ROOT" ]; then
    case "$CANONICAL_FILE_PATH" in
      "$REPO_ROOT"/mobile/*) ;;
      *) REPO_ROOT="" ;;
    esac
  fi
  if [ -n "$REPO_ROOT" ] && [ ! -f "$REPO_ROOT/mobile/.dart_tool/package_config.json" ]; then
    emit_system_message "Skipped Dart format/analyze because $REPO_ROOT/mobile/.dart_tool/package_config.json is missing. Run \`cd mobile && flutter pub get\` before relying on post-edit analysis in this worktree."
  fi

  if [ "$DART_READY" = false ]; then
    if ! resolve_dart_runner; then
      emit_block "Unable to run the repository Dart SDK: $DART_RESOLUTION_REASON"
    fi
    DART_READY=true
  fi

  ABS_PATH=$(cd "$(dirname "$FILE_PATH")" && pwd)/$(basename "$FILE_PATH")

  FORMAT_OUTPUT=""
  if ! FORMAT_OUTPUT=$(run_repo_dart "$DART_MOBILE_DIR" format "$ABS_PATH" 2>&1); then
    emit_block "Dart formatting failed for $FILE_PATH:\n$FORMAT_OUTPUT"
  fi

  ANALYSIS_RC=0
  ANALYSIS_OUTPUT=$(run_repo_dart "$DART_MOBILE_DIR" analyze "$ABS_PATH" 2>&1) || ANALYSIS_RC=$?
  DIAGNOSTICS=$(printf '%s\n' "$ANALYSIS_OUTPUT" \
    | grep -E '^[[:space:]]*(error|warning|info)[[:space:]]+-[[:space:]]' \
    | head -10 || true)

  if [ -n "$DIAGNOSTICS" ]; then
    emit_block "Analyzer diagnostics in $FILE_PATH:\n$DIAGNOSTICS\n\nPlease fix these issues before continuing."
  fi

  if [ "$ANALYSIS_RC" -ne 0 ]; then
    emit_block "Dart analysis failed for $FILE_PATH:\n$ANALYSIS_OUTPUT"
  fi
done <<EOF
$FILES
EOF

exit 0
