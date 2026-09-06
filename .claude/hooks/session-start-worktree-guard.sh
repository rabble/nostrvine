#!/usr/bin/env bash
# SessionStart hook: warn when another live Claude Code session may be using
# this git worktree.
#
# Two agent sessions writing one working tree is a silent hazard. In the
# incident that prompted this hook, one session ran an authorized
# `git reset --hard` while a second was still reasoning from a pre-reset
# snapshot; the second read the result as data loss and "restored" work that
# had been discarded on purpose. No permission prompt catches this -- both
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
# Detection prefers Claude Code's pid-keyed session registry. The registry cwd
# is the session's working root; it changes when the harness enters a worktree,
# but not for a `cd` inside an ephemeral Bash tool call. The Claude process cwd
# from lsof is the process cwd. On current macOS Claude that tracks harness
# chdir, so the two roots usually match; comparing both still covers sessions
# whose cwd lsof cannot read, and any case where the roots differ. A launch-root
# match is never suppressed: tools can still write absolute paths.
#
# The registry is undocumented Claude Code internal state, macOS-verified only,
# and includes a version field because its shape may change. If it is absent,
# unreadable, incompatible, empty of live confirmed records, or jq is
# unavailable, the hook falls back to $XDG_RUNTIME_DIR/cc-socks (Linux) and
# /tmp/cc-socks*/<pid>.sock. Set CLAUDE_SESSIONS_DIR, CC_SOCK_DIR, and
# CLAUDE_PROC_STAT_DIR to test or override those locations.
#
# Always exits 0. This warns; it never blocks a session.

set -uo pipefail

root="${CLAUDE_PROJECT_DIR:-$PWD}"
mine=$(git -C "$root" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -n "$mine" ] || exit 0

# Walk up the process tree to find this session's own claude pid, so the
# guard never reports itself in either detection mode.
self=""
p=$$
for _ in 1 2 3 4 5 6 7 8; do
  { [ -n "$p" ] && [ "$p" != "0" ] && [ "$p" != "1" ]; } || break
  cm=$(ps -o comm= -p "$p" 2>/dev/null)
  [ "${cm##*/}" = "claude" ] && { self="$p"; break; }
  p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
done

# Claude records procStart in UTC and in the C locale, but `ps -o lstart=`
# renders month and weekday names through LC_TIME, so an unpinned locale makes
# every record mismatch and silently empties the registry path. Linux Claude
# stores /proc starttime jiffies instead; accept either shape.
process_start_utc() {
  TZ=UTC LC_ALL=C ps -o lstart= -p "$1" 2>/dev/null \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

process_start_matches() {
  local pid="$1" recorded="$2" actual stat_file rest
  recorded=$(printf '%s\n' "$recorded" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  case "$recorded" in
    '' | *[!0-9]*)
      actual=$(process_start_utc "$pid")
      [ -n "$actual" ] && [ "$actual" = "$recorded" ]
      ;;
    *)
      stat_file="${CLAUDE_PROC_STAT_DIR:-/proc}/${pid}/stat"
      [ -r "$stat_file" ] || return 1
      rest=$(sed 's/.*) //' "$stat_file")
      actual=$(printf '%s\n' "$rest" | awk '{print $20}')
      [ -n "$actual" ] && [ "$actual" = "$recorded" ]
      ;;
  esac
}

process_cwd() {
  lsof -a -p "$1" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1
}

append_registry_match() {
  local pid="$1" name="$2" status="$3" launch_root="$4" session_root="$5"
  local label detail

  label="pid ${pid}"
  [ -n "$name" ] && label="${name}, pid ${pid}"
  [ -n "$status" ] && label="${label} (${status})"

  if [ "$launch_root" = "$mine" ] && [ "$session_root" = "$mine" ]; then
    detail="launch and session roots both match this worktree"
  elif [ "$launch_root" = "$mine" ] && [ -n "$session_root" ]; then
    detail="launched here, now working in ${session_root} -- likely not a conflict, but it can still write here by absolute path"
  elif [ "$launch_root" = "$mine" ]; then
    detail="launched here; current session root is unavailable -- it can still write here by absolute path"
  elif [ -n "$launch_root" ]; then
    detail="now working here after launching from ${launch_root} -- active worktree match"
  else
    detail="active session root matches this worktree; launch root is unavailable"
  fi

  count=$((count + 1))
  others="${others}  - ${label}: ${detail}"$'\n'
}

count=0
others=""
registry_supported=false
sessions_dir="${CLAUDE_SESSIONS_DIR:-${HOME:-}/.claude/sessions}"

if command -v jq >/dev/null 2>&1 && [ -d "$sessions_dir" ] && [ -r "$sessions_dir" ]; then
  shopt -s nullglob
  for session_file in "$sessions_dir"/*.json; do
    if ! registry_record=$(jq -er '
      select(
        (.pid | type == "number") and
        (.procStart | type == "string") and
        (.cwd | type == "string") and
        (.version | type == "string") and
        (.kind | type == "string") and
        (.entrypoint | type == "string")
      )
      | [
          (.pid | tostring),
          .procStart,
          .cwd,
          .kind,
          .entrypoint,
          (.name // "" | tostring),
          (.status // "" | tostring)
        ]
      | map(gsub("[\u0000-\u001f\u007f]"; " "))
      | join("\u001f")
    ' "$session_file" 2>/dev/null); then
      continue
    fi

    IFS=$'\x1f' read -r pid recorded_start session_cwd kind entrypoint name status \
      <<< "$registry_record"
    case "$pid" in '' | *[!0-9]*) continue ;; esac
    [ "$pid" = "$self" ] && continue
    [ "$kind" = "interactive" ] || continue
    [ "$entrypoint" = "cli" ] || continue

    cm=$(ps -o comm= -p "$pid" 2>/dev/null)
    [ "${cm##*/}" = "claude" ] || continue
    process_start_matches "$pid" "$recorded_start" || continue
    registry_supported=true

    launch_cwd=$(process_cwd "$pid")
    launch_root=""
    session_root=""
    if [ -n "$launch_cwd" ]; then
      launch_root=$(git -C "$launch_cwd" rev-parse --show-toplevel 2>/dev/null) || launch_root=""
    fi
    if [ -n "$session_cwd" ]; then
      session_root=$(git -C "$session_cwd" rev-parse --show-toplevel 2>/dev/null) || session_root=""
    fi
    if [ "$launch_root" != "$mine" ] && [ "$session_root" != "$mine" ]; then
      continue
    fi

    append_registry_match "$pid" "$name" "$status" "$launch_root" "$session_root"
  done
  shopt -u nullglob
fi

if [ "$registry_supported" = false ]; then
  sock_dirs=()
  if [ -n "${CC_SOCK_DIR:-}" ]; then
    sock_dirs=("$CC_SOCK_DIR")
  else
    if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "$XDG_RUNTIME_DIR/cc-socks" ]; then
      sock_dirs+=("$XDG_RUNTIME_DIR/cc-socks")
    fi
    for dir in /tmp/cc-socks*; do
      [ -d "$dir" ] || continue
      sock_dirs+=("$dir")
    done
  fi

  if [ "${#sock_dirs[@]}" -gt 0 ]; then
    while read -r pid cm; do
      case "$pid" in '' | *[!0-9]*) continue ;; esac
      [ "$pid" = "$self" ] && continue
      [ "${cm##*/}" = "claude" ] || continue

      has_socket=false
      for dir in "${sock_dirs[@]}"; do
        [ -S "$dir/$pid.sock" ] || continue
        has_socket=true
        break
      done
      [ "$has_socket" = true ] || continue

      cwd=$(process_cwd "$pid")
      [ -n "$cwd" ] || continue
      their=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || continue
      [ "$their" = "$mine" ] || continue

      count=$((count + 1))
      others="${others}  - pid ${pid} (cwd ${cwd})"$'\n'
    done < <(ps -eo pid=,comm= 2>/dev/null)
  fi
fi

[ "$count" -gt 0 ] || exit 0

plural="session"
verb="has"
if [ "$count" -ne 1 ]; then
  plural="sessions"
  verb="have"
fi

if ! command -v jq >/dev/null 2>&1; then
  printf 'Session worktree guard detected %s other Claude %s associated with %s, but jq is unavailable; skipping JSON warning.\n' \
    "$count" "$plural" "$mine" >&2
  exit 0
fi

if [ "$registry_supported" = true ]; then
  signal_description="a launch or active session root associated with this worktree"
else
  signal_description="a launch root matching this worktree according to the legacy socket fallback"
fi

human="⚠️  ${count} other Claude ${plural} ${verb} ${signal_description}:
${others}
  worktree: ${mine}

Reading together is fine. If both sessions will EDIT code or run git state commands (reset/checkout/stash), give this task its own worktree:
  git worktree add .worktrees/<task> -b <branch> origin/main"

agent="CONCURRENCY WARNING: ${count} other live Claude Code ${plural} ${verb} ${signal_description} (${mine}).
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
