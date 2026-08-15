#!/usr/bin/env bash
# SessionStart hook: warn when another live Claude Code session already has
# this git worktree open.
#
# Two agent sessions writing one working tree is a silent hazard. In the
# incident that prompted this hook, one session ran an authorized
# `git reset --hard` while a second was still reasoning from a pre-reset
# snapshot; the second read the result as data loss and "restored" work that
# had been discarded on purpose. No permission prompt catches this — both
# sessions were doing exactly what they had been told.
#
# Sharing a worktree read-only is fine. Concurrent *writers* are the problem,
# which is what `.claude/rules/agent_workflow.md` §1 already rules out.
#
# Opt in from your personal .claude/settings.local.json:
#
#   "SessionStart": [
#     {
#       "matcher": "startup|resume",
#       "hooks": [
#         {
#           "type": "command",
#           "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/session-start-worktree-guard.sh",
#           "timeout": 10,
#           "statusMessage": "Checking for concurrent sessions..."
#         }
#       ]
#     }
#   ]
#
# Deliberately not registered in the team settings.json: anyone already running
# it at user scope would get the warning twice.
#
# Detection: each live session owns a /tmp/cc-socks*/<pid>.sock socket. For
# every other live Claude process with a matching socket, resolve its cwd and
# compare canonical worktree roots. If no socket directory exists on your setup,
# the hook is a silent no-op. Set CC_SOCK_DIR to test or override the socket dir.
#
# Always exits 0. This warns; it never blocks a session.

set -uo pipefail

SOCK_DIRS=()
if [ -n "${CC_SOCK_DIR:-}" ]; then
  SOCK_DIRS=("$CC_SOCK_DIR")
else
  for dir in /tmp/cc-socks*; do
    [ -d "$dir" ] || continue
    SOCK_DIRS+=("$dir")
  done
fi

root="${CLAUDE_PROJECT_DIR:-$PWD}"
mine=$(git -C "$root" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -n "$mine" ] || exit 0
mine=$(cd "$mine" 2>/dev/null && pwd -P) || exit 0
[ "${#SOCK_DIRS[@]}" -gt 0 ] || exit 0

# Walk up the process tree to find this session's own claude pid, so the
# guard never reports itself.
self=""
p=$$
for _ in 1 2 3 4 5 6 7 8; do
  { [ -n "$p" ] && [ "$p" != "0" ] && [ "$p" != "1" ]; } || break
  cm=$(ps -o comm= -p "$p" 2>/dev/null)
  [ "${cm##*/}" = "claude" ] && { self="$p"; break; }
  p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
done

others=""
count=0
while read -r pid cm; do
  case "$pid" in '' | *[!0-9]*) continue ;; esac
  [ "$pid" = "$self" ] && continue
  [ "${cm##*/}" = "claude" ] || continue

  has_socket=false
  for dir in "${SOCK_DIRS[@]}"; do
    [ -S "$dir/$pid.sock" ] || continue
    has_socket=true
    break
  done
  [ "$has_socket" = true ] || continue

  cwd=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1)
  [ -n "$cwd" ] || continue

  their=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || continue
  their=$(cd "$their" 2>/dev/null && pwd -P) || continue
  # Different worktrees of the same repo are the pattern agent_workflow.md
  # asks for, not a collision. Only an identical working tree matters.
  [ "$their" = "$mine" ] || continue

  count=$((count + 1))
  others="${others}  - pid ${pid} (cwd ${cwd})"$'\n'
done < <(ps -eo pid=,comm= 2>/dev/null)

[ "$count" -gt 0 ] || exit 0

command -v jq >/dev/null 2>&1 || exit 0

plural="session"
verb="has"
if [ "$count" -ne 1 ]; then
  plural="sessions"
  verb="have"
fi

human="⚠️  ${count} other Claude ${plural} already ${verb} this worktree open:
${others}
  worktree: ${mine}

Reading together is fine. If both sessions will EDIT code or run git state commands (reset/checkout/stash), give this task its own worktree:
  git worktree add .worktrees/<task> -b <branch> origin/main"

agent="CONCURRENCY WARNING: ${count} other live Claude Code ${plural} currently ${verb} this same git worktree open (${mine}).
${others}
Consequences to respect this session:
- Your git snapshot may go stale at any moment; re-check \`git status\` before reasoning about working-tree state, and never assume an unexpected change was an accident.
- Do not run destructive git commands (reset --hard, checkout --, stash, clean) without confirming with the user first.
- Prefer a separate worktree for any code edits."

jq -n \
  --arg human "$human" \
  --arg agent "$agent" \
  '{
    systemMessage: $human,
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $agent
    }
  }' || exit 0
