#!/bin/bash
# Hook: PreToolUse (Edit|Write)
# Block edits that use raw Colors.* instead of VineTheme
#
# Enforces: Always use VineTheme / context.vineColors instead of raw Colors.*
#           (Divine ships both a dark and a light appearance)
# Allowed: Colors.transparent (universal constant)
# Input: JSON with tool_input (old_string, new_string for Edit; content for Write)
# Output: JSON with permissionDecision: "deny" if violation found

set -e

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only check Dart files in lib/ (skip tests, they may need raw colors for mocking)
if [[ ! "$FILE_PATH" =~ \.dart$ ]] || [[ ! "$FILE_PATH" =~ /lib/ ]]; then
  exit 0
fi

# Get the content being written/edited
if [ "$TOOL_NAME" = "Edit" ]; then
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // empty')
elif [ "$TOOL_NAME" = "Write" ]; then
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
else
  exit 0
fi

# Skip if no content
if [ -z "$CONTENT" ]; then
  exit 0
fi

# Check for any Colors.* usage except Colors.transparent.
# Strip the allowed forms first, then check for remaining Colors.*:
#   - Colors.transparent          universal constant
#   - <x>.vineColors.<token>      semantic palette accessor (VineThemeColors),
#                                 whose member reads end in "Colors.<token>"
#   - VineThemeColors             the palette type itself
FILTERED_CONTENT=$(echo "$CONTENT" |
  sed -e 's/Colors\.transparent//g' \
      -e 's/vineColors\.//g' \
      -e 's/VineThemeColors//g')

if echo "$FILTERED_CONTENT" | grep -qE 'Colors\.[a-zA-Z]'; then
  # Extract the specific violation for the error message
  VIOLATION=$(echo "$FILTERED_CONTENT" | grep -oE 'Colors\.[a-zA-Z]+' | head -1)

  REASON="VineTheme violation: Found '$VIOLATION'. Per project rules: Always use VineTheme color constants instead of raw Colors.* (only Colors.transparent is allowed)."
  jq -n --arg reason "$REASON" '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": $reason
    }
  }'
  exit 0
fi

# No violation - allow the edit
exit 0
