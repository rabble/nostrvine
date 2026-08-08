#!/bin/bash
# Hook: PreToolUse (Edit|Write)
# Block edits that use raw Colors.* instead of VineTheme
#
# Enforces: Always use VineTheme color constants for dark-mode-only app
# Allowed: Colors.transparent (universal constant)
# Input: Codex hook JSON with an apply_patch command in tool_input.command
# Output: JSON with permissionDecision: "deny" if violation found

set -e

INPUT=$(cat)
# Inspect only added lines inside lib/*.dart sections of the apply_patch payload.
PATCH=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
CONTENT=$(printf '%s\n' "$PATCH" | awk '
  /^\*\*\* (Add|Update) File: / {
    dart_lib = ($0 ~ /\.dart$/ && $0 ~ /(^|[[:space:]\/])lib\//)
    next
  }
  /^\*\*\* Move to: / {
    dart_lib = ($0 ~ /\.dart$/ && $0 ~ /(^|[[:space:]\/])lib\//)
    next
  }
  /^\*\*\* (Delete File:|End Patch)/ { dart_lib = 0; next }
  dart_lib && /^\+/ { sub(/^\+/, ""); print }
')

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
