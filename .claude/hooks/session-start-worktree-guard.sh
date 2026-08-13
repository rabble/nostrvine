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
# Detection: each live session owns /tmp/cc-socks/<pid>.sock. For every other
# live session, resolve its cwd and compare worktree roots. If that directory
# does not exist on your setup, the hook is a silent no-op.
#
# Always exits 0. This warns; it never blocks a session.

set -uo pipefail

SOCK_DIR="/tmp/cc-socks"

root="${CLAUDE_PROJECT_DIR:-$PWD}"
mine=$(git -C "$root" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -n "$mine" ] || exit 0
[ -d "$SOCK_DIR" ] || exit 0

# Walk up the process tree to find this session's own claude pid, so the
# guard never reports itself.
self=""
p=$$
for _ in 1 2 3 4 5 6 7 8; do
  { [ -n "$p" ] && [ "$p" != "0" ] && [ "$p" != "1" ]; } || break
  cm=$(ps -o comm= -p "$p" 2>/dev/null)
  case "$cm" in */claude) self="$p"; break ;; esac
  p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
done

others=""
count=0
for sock in "$SOCK_DIR"/*.sock; do
  [ -S "$sock" ] || continue
  pid="${sock##*/}"
  pid="${pid%.sock}"
  case "$pid" in '' | *[!0-9]*) continue ;; esac
  [ "$pid" = "$self" ] && continue

  # Stale socket from a crashed session.
  ps -p "$pid" -o comm= >/dev/null 2>&1 || continue

  cwd=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1)
  [ -n "$cwd" ] || continue

  their=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || continue
  # Different worktrees of the same repo are the pattern agent_workflow.md
  # asks for, not a collision. Only an identical working tree matters.
  [ "$their" = "$mine" ] || continue

  count=$((count + 1))
  others="${others}  - pid ${pid} (cwd ${cwd})"$'\n'
done

[ "$count" -gt 0 ] || exit 0

python3 - "$mine" "$count" "$others" <<'PY'
import json, sys

worktree, count, others = sys.argv[1], int(sys.argv[2]), sys.argv[3].rstrip("\n")
plural = "session" if count == 1 else "sessions"

human = (
    f"⚠️  {count} other Claude {plural} already has this worktree open:\n"
    f"{others}\n"
    f"  worktree: {worktree}\n\n"
    "Reading together is fine. If both sessions will EDIT code or run git "
    "state commands (reset/checkout/stash), give this task its own worktree:\n"
    "  git worktree add .worktrees/<task> -b <branch> origin/main"
)

agent = (
    f"CONCURRENCY WARNING: {count} other live Claude Code {plural} "
    f"currently has this same git worktree open ({worktree}).\n{others}\n"
    "Consequences to respect this session:\n"
    "- Your git snapshot may go stale at any moment; re-check `git status` "
    "before reasoning about working-tree state, and never assume an "
    "unexpected change was an accident.\n"
    "- Do not run destructive git commands (reset --hard, checkout --, "
    "stash, clean) without confirming with the user first.\n"
    "- Prefer a separate worktree for any code edits."
)

print(json.dumps({
    "systemMessage": human,
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": agent,
    },
}))
PY
