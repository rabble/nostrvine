#!/bin/bash
# Hook: PostToolUse (Edit|Write)
# Ensure edited Dart files have 0 analyzer diagnostics (error/warning/info)
#
# Input: Codex hook JSON with an apply_patch command in tool_input.command
# Output: JSON with decision: "block" if errors found

set -e

# Read JSON input from stdin
INPUT=$(cat)

# Extract changed file paths from Codex's apply_patch payload.
PATCH=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
FILES=$(printf '%s\n' "$PATCH" | sed -nE \
  -e 's/^\*\*\* (Add|Update) File: (.*)$/\2/p' \
  -e 's/^\*\*\* Move to: (.*)$/\1/p')

[ -n "$FILES" ] || exit 0

while IFS= read -r FILE_PATH; do
  [[ "$FILE_PATH" =~ \.dart$ ]] || continue
  [ -f "$FILE_PATH" ] || continue

  ANALYSIS_OUTPUT=$(dart analyze "$FILE_PATH" 2>&1 || true)
  if echo "$ANALYSIS_OUTPUT" | grep -q " error \| warning \| info "; then
    ERRORS=$(echo "$ANALYSIS_OUTPUT" | grep " error \| warning \| info " | head -10)
    REASON="Analyzer errors in $FILE_PATH:\n$ERRORS\n\nPlease fix these issues before continuing."
    jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
    exit 0
  fi
done <<EOF
$FILES
EOF

exit 0
