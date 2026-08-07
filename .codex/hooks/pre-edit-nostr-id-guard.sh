#!/bin/bash
# Hook: PreToolUse (Edit|Write)
# Block edits that truncate Nostr IDs
#
# Detects truncation patterns on Nostr ID variables (id, pubkey, eventId, etc.)
# Exception: pubkey truncation paired with ellipsis for UI display-name
#   fallbacks is allowed (e.g. bestDisplayName getters that show a shortened
#   pubkey when no name is available).
#
# Input: Codex hook JSON with an apply_patch command in tool_input.command
# Output: JSON with permissionDecision: "deny" if violation found

set -e

INPUT=$(cat)
# Inspect only added lines inside Dart file sections of the apply_patch payload.
PATCH=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
CONTENT=$(printf '%s\n' "$PATCH" | awk '
  /^\*\*\* (Add|Update) File: / { dart = ($0 ~ /\.dart$/); next }
  /^\*\*\* Move to: / { dart = ($0 ~ /\.dart$/); next }
  /^\*\*\* (Delete File:|End Patch)/ { dart = 0; next }
  dart && /^\+/ { sub(/^\+/, ""); print }
')

# Skip if no content
if [ -z "$CONTENT" ]; then
  exit 0
fi

# Nostr ID variable name pattern
ID_VARS='(id|Id|ID|pubkey|Pubkey|eventId|noteId|npub|nsec)'
# Truncation method pattern
TRUNC_CALL='\.(substring|take)[[:space:]]*\([[:space:]]*0?[[:space:]]*,?[[:space:]]*[0-9]{1,2}[[:space:]]*\)'

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
  if echo "$LINE" | grep -qE 'pubkey\.substring' && echo "$LINE" | grep -qE '(displayName|name)[[:space:]]*\?\?'; then
    continue
  fi

  VIOLATION="$LINE"
  break
done <<< "$CONTENT"

# Also check string interpolations with ID truncation
if [ -z "$VIOLATION" ]; then
  while IFS= read -r LINE; do
    if ! echo "$LINE" | grep -qE '\$\{[^}]*'"${ID_VARS}"'\.substring[[:space:]]*\([[:space:]]*0[[:space:]]*,'; then
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
