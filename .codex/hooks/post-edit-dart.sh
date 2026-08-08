#!/bin/bash
# Hook: PostToolUse (Edit|Write)
# Format edited Dart files, then require zero analyzer diagnostics.

set -e

HOOK_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/dart-runner.sh
source "$HOOK_DIR/lib/dart-runner.sh"

emit_block() {
  jq -n --arg reason "$1" '{decision: "block", reason: $reason}'
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
