#!/bin/bash
# Hook: PostToolUse (Edit|Write)
# Auto-format Dart files after edits
#
# Input: JSON with tool_input.file_path
# Output: None (exit 0 on success)

set -e

# Read JSON input from stdin
INPUT=$(cat)

# Extract file path from tool input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only process Dart files
if [[ -z "$FILE_PATH" || ! "$FILE_PATH" =~ \.dart$ ]]; then
  exit 0
fi

# Check if file exists
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Format the file
dart format "$FILE_PATH" 2>/dev/null || true

exit 0
