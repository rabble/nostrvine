#!/bin/bash
# Block git commit/push if git hooks aren't installed (CI checks won't be caught locally)
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$COMMAND" ] && exit 0

# Only care about git commit/push commands
FIRST_CMD=$(echo "$COMMAND" | head -1 | sed 's/\s*&&.*//' | sed 's/\s*|.*//' | sed 's/\s*;.*//')
echo "$FIRST_CMD" | grep -qE '^\s*git\s+(commit|push)\b' || exit 0

REPO_ROOT=$(git -C "$CLAUDE_PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null) || exit 0
GIT_COMMON_DIR=$(git -C "$REPO_ROOT" rev-parse --git-common-dir 2>/dev/null) || exit 0
[[ "$GIT_COMMON_DIR" != /* ]] && GIT_COMMON_DIR="$(cd "$REPO_ROOT/$GIT_COMMON_DIR" && pwd)"

if [ ! -f "$GIT_COMMON_DIR/hooks/pre-commit" ] || [ ! -f "$GIT_COMMON_DIR/hooks/pre-push" ]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Git hooks not installed — CI checks won'\''t be caught locally. Run: cd mobile && mise run setup_hooks"
    }
  }'
fi
