#!/bin/bash
# Hook: PostToolUse (Edit|Write)
# Auto-format Dart files after edits
#
# Input: Codex hook JSON with an apply_patch command in tool_input.command
# Output: None (exit 0 on success)

set -e

# Read JSON input from stdin
INPUT=$(cat)

# Extract changed file paths from Codex's apply_patch payload. Hook commands run
# with the session cwd, so these paths resolve exactly as they did for the edit.
PATCH=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
FILES=$(printf '%s\n' "$PATCH" | sed -nE \
  -e 's/^\*\*\* (Add|Update) File: (.*)$/\2/p' \
  -e 's/^\*\*\* Move to: (.*)$/\1/p')

[ -n "$FILES" ] || exit 0

while IFS= read -r FILE_PATH; do
  [[ "$FILE_PATH" =~ \.dart$ ]] || continue
  [ -f "$FILE_PATH" ] || continue
  dart format "$FILE_PATH" 2>/dev/null || true
done <<EOF
$FILES
EOF

exit 0
