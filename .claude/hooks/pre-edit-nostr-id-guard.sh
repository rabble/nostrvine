#!/bin/bash
# Hook: PreToolUse (Edit|Write)
# Block edits that truncate Nostr IDs
#
# Detects patterns like: .substring(0, 8), .take(8), id.substring(0, N)
# Input: JSON with tool_input (old_string, new_string for Edit; content for Write)
# Output: JSON with permissionDecision: "deny" if violation found

set -e

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

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

# Patterns that indicate Nostr ID truncation
# - .substring(0, 8) or similar short lengths
# - .take(8) or similar
# - Logging with truncated IDs
VIOLATION=""

# Check for substring truncation on IDs (common patterns)
if echo "$CONTENT" | grep -qE '\.(substring|take)\s*\(\s*0?\s*,?\s*[0-9]{1,2}\s*\)'; then
  # More specific check - look for ID-related variable names
  if echo "$CONTENT" | grep -qE '(id|Id|ID|pubkey|Pubkey|eventId|noteId|npub|nsec)\.(substring|take)\s*\(\s*0?\s*,?\s*[0-9]{1,2}\s*\)'; then
    VIOLATION="Nostr ID truncation detected (e.g., id.substring(0, 8))"
  fi
fi

# Check for string interpolation with substring on IDs
if echo "$CONTENT" | grep -qE '\$\{[^}]*(id|Id|pubkey|eventId)\.substring\s*\(\s*0\s*,'; then
  VIOLATION="Nostr ID truncation in string interpolation"
fi

if [ -n "$VIOLATION" ]; then
  jq -n --arg reason "$VIOLATION. Per project rules: NEVER truncate Nostr IDs. Use full 64-character hex IDs or UI ellipsis for display." '{
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
