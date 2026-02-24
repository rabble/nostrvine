#!/bin/bash
# Hook: PreToolUse (Edit|Write)
# Block edits that truncate Nostr IDs
#
# Detects truncation patterns on Nostr ID variables (id, pubkey, eventId, etc.)
# Exception: pubkey truncation paired with ellipsis for UI display-name
#   fallbacks is allowed (e.g. bestDisplayName getters that show a shortened
#   pubkey when no name is available).
#
# Input: JSON with tool_input (old_string, new_string for Edit; content for Write)
# Output: JSON with permissionDecision: "deny" if violation found

set -e

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only check Dart files (skip JS, HTML, etc.)
if [[ ! "$FILE_PATH" =~ \.dart$ ]]; then
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

# Nostr ID variable name pattern
ID_VARS='(id|Id|ID|pubkey|Pubkey|eventId|noteId|npub|nsec)'
# Truncation method pattern
TRUNC_CALL='\.(substring|take)\s*\(\s*0?\s*,?\s*[0-9]{1,2}\s*\)'

VIOLATION=""

# Check each line individually so we can apply per-line exceptions
while IFS= read -r LINE; do
  # Skip lines without truncation patterns
  if ! echo "$LINE" | grep -qE "$TRUNC_CALL"; then
    continue
  fi

  # Skip lines that aren't about Nostr ID variables
  if ! echo "$LINE" | grep -qE "${ID_VARS}${TRUNC_CALL}"; then
    continue
  fi

  # Exception: pubkey truncation with ellipsis (UI display-name fallback)
  if echo "$LINE" | grep -qE 'pubkey\.(substring|take)' && echo "$LINE" | grep -qF '...'; then
    continue
  fi

  # Exception: pubkey in a display-name fallback chain (displayName ?? name ?? pubkey.substring)
  if echo "$LINE" | grep -qE 'pubkey\.substring' && echo "$LINE" | grep -qE '(displayName|name)\s*\?\?'; then
    continue
  fi

  VIOLATION="$LINE"
  break
done <<< "$CONTENT"

# Also check string interpolations with ID truncation
if [ -z "$VIOLATION" ]; then
  while IFS= read -r LINE; do
    if ! echo "$LINE" | grep -qE '\$\{[^}]*'"${ID_VARS}"'\.substring\s*\(\s*0\s*,'; then
      continue
    fi

    # Exception: pubkey display interpolation with ellipsis
    if echo "$LINE" | grep -qE '\$\{[^}]*pubkey\.substring' && echo "$LINE" | grep -qF '...'; then
      continue
    fi

    VIOLATION="$LINE"
    break
  done <<< "$CONTENT"
fi

if [ -n "$VIOLATION" ]; then
  REASON="Nostr ID truncation detected. Per project rules: NEVER truncate Nostr IDs. Use full 64-character hex IDs or UI ellipsis for display."
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
