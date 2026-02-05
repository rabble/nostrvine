#!/bin/bash
# Hook: PostToolUse (Edit|Write)
# Ensure edited Dart files have 0 analyzer errors
#
# Input: JSON with tool_input.file_path
# Output: JSON with decision: "block" if errors found

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

# Run analyzer on the specific file
ANALYSIS_OUTPUT=$(dart analyze "$FILE_PATH" 2>&1 || true)

# Count errors (not warnings or infos)
ERROR_COUNT=$(echo "$ANALYSIS_OUTPUT" | grep -c " - " | grep -v "info" || echo "0")

# Check if there are any errors or warnings
if echo "$ANALYSIS_OUTPUT" | grep -q " error \| warning "; then
  # Extract just the error/warning lines
  ERRORS=$(echo "$ANALYSIS_OUTPUT" | grep " error \| warning " | head -10)

  cat << EOF
{
  "decision": "block",
  "reason": "Analyzer errors in $FILE_PATH:\n$ERRORS\n\nPlease fix these issues before continuing."
}
EOF
  exit 0
fi

exit 0
