#!/usr/bin/env bash
# SessionEnd hook: purge Flutter build artifacts from a linked worktree when
# the session ends, so abandoned worktrees stop accumulating disk.
#
# Why not `flutter clean`: `mobile/` is a Dart pub workspace. `flutter clean`
# in `mobile/` only clears `mobile/build` + `mobile/.dart_tool` (~4.6 GB of a
# typical 8 GB tree). It does not recurse into workspace packages, and
# `mobile/packages/*/build` is another ~3.2 GB. Removing the directories
# directly gets all of it and skips the Flutter tool startup entirely.
#
# Only linked worktrees are cleaned. The main checkout keeps its build cache
# because it is the one you return to most; worktrees are what pile up.
#
# Registered in .claude/settings.json (team-wide), not settings.local.json.
# That file is gitignored, so it exists only in the main checkout — and this
# hook deliberately skips the main checkout. Registering it personally means
# it is present only where it refuses to run, and absent from every linked
# worktree, which is the only place it does anything.
set -euo pipefail

root="${CLAUDE_PROJECT_DIR:-$PWD}"

is_ancestor_pid() {
  local needle="$1"
  local p="$$"
  local parent=""

  for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
    [ -n "$p" ] || break
    [ "$p" = "$needle" ] && return 0
    parent="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')"
    [ -n "$parent" ] || break
    [ "$parent" != "$p" ] || break
    p="$parent"
  done

  return 1
}

active_worktree_peers() {
  command -v ps >/dev/null 2>&1 || return 0
  command -v lsof >/dev/null 2>&1 || return 0

  local pid=""
  local command_name=""
  local command_base=""
  local cwd=""
  local count=0
  local peers=""

  while read -r pid command_name; do
    case "$pid" in '' | *[!0-9]*) continue ;; esac
    is_ancestor_pid "$pid" && continue

    command_base="${command_name##*/}"
    case "$command_base" in
      bash|sh|zsh|fish|claude|codex|flutter|dart|java|gradle|xcodebuild|swift|node|npm|pnpm|yarn|mise|python|python3) ;;
      *) continue ;;
    esac

    cwd="$(lsof -b -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1)"
    [ -n "$cwd" ] || continue
    case "$cwd" in
      "$root"|"$root"/*) ;;
      *) continue ;;
    esac

    count=$((count + 1))
    [ "$count" -le 5 ] && peers="${peers}  - pid ${pid} (${command_name:-unknown}, cwd ${cwd})"$'\n'
  done < <(ps -eo pid=,comm= 2>/dev/null || true)

  [ "$count" -gt 0 ] || return 0

  if [ "$count" -gt 5 ]; then
    peers="${peers}  - and $((count - 5)) more process(es)"$'\n'
  fi

  printf '%s\t%s' "$count" "$peers"
}

input=""
if [ ! -t 0 ]; then
  input="$(cat || true)"
fi
reason="$(printf '%s' "$input" | jq -r '.reason // empty' 2>/dev/null || true)"
case "$reason" in
  logout|prompt_input_exit|bypass_permissions_disabled) ;;
  *) exit 0 ;;
esac

# Only meaningful in a divine-mobile checkout.
[ -f "$root/mobile/pubspec.yaml" ] || exit 0

# A linked worktree's git dir lives at <repo>/.git/worktrees/<name>; the main
# checkout's does not. Skip the main checkout.
gitdir="$(git -C "$root" rev-parse --absolute-git-dir 2>/dev/null || true)"
case "$gitdir" in
  */.git/worktrees/*) ;;
  *) exit 0 ;;
esac

if [ "${CLAUDE_PURGE_SKIP_PEER_SCAN:-0}" != "1" ]; then
  peer_scan="$(active_worktree_peers)"
  if [ -n "$peer_scan" ]; then
    peer_count="${peer_scan%%	*}"
    peer_list="${peer_scan#*	}"
    jq -n \
      --arg count "$peer_count" \
      --arg root "$root" \
      --arg peers "$peer_list" \
      '{systemMessage: ("Skipped build-artifact purge for " + $root + " because " + $count + " other live process(es) have cwd inside this worktree:\n" + $peers + "Run the purge after the other session or terminal exits.")}'
    exit 0
  fi
fi

# Stage removals under the linked worktree gitdir, then delete detached.
# Renaming within a filesystem is instant, so the session exits immediately
# instead of waiting on tens of GB of unlink; a killed background rm just
# leaves the staging dir for the next run to collect.
trash="$gitdir/claude-purge"
if [ -d "$trash" ]; then
  leftover="$trash.$$"
  if mv "$trash" "$leftover" 2>/dev/null; then
    nohup rm -rf "$leftover" >/dev/null 2>&1 &
  fi
fi

# The gitdir lives in the main checkout's filesystem, which is not always the
# worktree's: a cross-device mv degrades to a synchronous full copy that can
# blow the hook timeout and, when killed, leaves the source intact to fail the
# same way next run. Delete in place instead, still detached. When stat cannot
# report a device id (non-GNU stat), both sides are empty and compare equal,
# preserving the staging path.
if [ "$(stat -c %d "$root/mobile" 2>/dev/null)" != "$(stat -c %d "$gitdir" 2>/dev/null)" ]; then
  n=0
  dirs=()
  while IFS= read -r dir; do
    dirs+=("$dir")
    n=$((n + 1))
  done < <(find "$root/mobile" -type d \( -name build -o -name .dart_tool \) -prune 2>/dev/null)
  if [ "$n" -gt 0 ]; then
    nohup rm -rf "${dirs[@]}" >/dev/null 2>&1 &
    printf '{"systemMessage":"Purged %d build/.dart_tool dirs from %s"}\n' \
      "$n" "$(basename "$root")"
  fi
  exit 0
fi

mkdir -p "$trash"

n=0
while IFS= read -r dir; do
  mv "$dir" "$trash/$n" 2>/dev/null && n=$((n + 1)) || true
done < <(find "$root/mobile" -type d \( -name build -o -name .dart_tool \) -prune 2>/dev/null)

[ "$n" -gt 0 ] || { rmdir "$trash" 2>/dev/null || true; exit 0; }

# Detach so the unlink outlives the session.
nohup rm -rf "$trash" >/dev/null 2>&1 &

printf '{"systemMessage":"Purged %d build/.dart_tool dirs from %s"}\n' \
  "$n" "$(basename "$root")"
