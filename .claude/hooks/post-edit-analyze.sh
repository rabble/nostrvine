#!/bin/bash
# Hook: PostToolUse (Edit|Write)
# Ensure edited Dart files have 0 analyzer diagnostics (error/warning/info)
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

# If the build-artifact purge removed package resolution state, analyzer output
# is all missing-package noise until pub get runs again.
FILE_DIR=$(dirname "$FILE_PATH")
CANONICAL_FILE_PATH="$FILE_PATH"
if CANONICAL_FILE_DIR=$(cd -P "$FILE_DIR" 2>/dev/null && pwd); then
  CANONICAL_FILE_PATH="$CANONICAL_FILE_DIR/$(basename "$FILE_PATH")"
fi
REPO_ROOT=$(git -C "$FILE_DIR" rev-parse --show-toplevel 2>/dev/null || true)
if [[ -n "$REPO_ROOT" && "$CANONICAL_FILE_PATH" == "$REPO_ROOT"/mobile/* && ! -f "$REPO_ROOT/mobile/.dart_tool/package_config.json" ]]; then
  exit 0
fi

# Run analyzer on the specific file
ANALYSIS_OUTPUT=$(dart analyze "$FILE_PATH" 2>&1 || true)

# Check if there are any errors, warnings, or info diagnostics
if echo "$ANALYSIS_OUTPUT" | grep -q " error \| warning \| info "; then
  # Extract just the diagnostic lines
  ERRORS=$(echo "$ANALYSIS_OUTPUT" | grep " error \| warning \| info " | head -10)

  cat << EOF
{
  "decision": "block",
  "reason": "Analyzer errors in $FILE_PATH:\n$ERRORS\n\nPlease fix these issues before continuing."
}
EOF
  exit 0
fi

exit 0
