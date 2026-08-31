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

device_id() {
  stat -c %d "$1" 2>/dev/null || stat -f %d "$1" 2>/dev/null || true
}

input=""
if [ ! -t 0 ]; then
  input="$(cat || true)"
fi
reason="$(printf '%s' "$input" | jq -r '.reason // empty' 2>/dev/null || true)"
# Purge only for reasons Claude identifies as terminal. In particular, `other`
# is ambiguous (including headless exits), so deleting build state for it would
# trade more cleanup coverage for a risk of purging a session that may continue.
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
# report a device id, both sides are empty and compare equal, preserving the
# staging path. Unlike the staging branch, this in-place background deletion is
# not restart-atomic: an immediate rebuild can briefly race a half-removed tree.
if [ "$(device_id "$root/mobile")" != "$(device_id "$gitdir")" ]; then
  n=0
  dirs=()
  while IFS= read -r -d '' dir; do
    dirs+=("$dir")
    n=$((n + 1))
  done < <(find "$root/mobile" -type d \( -name build -o -name .dart_tool \) -prune -print0 2>/dev/null)
  if [ "$n" -gt 0 ]; then
    nohup rm -rf "${dirs[@]}" >/dev/null 2>&1 &
    printf '{"systemMessage":"Purged %d build/.dart_tool dirs from %s"}\n' \
      "$n" "$(basename "$root")"
  fi
  exit 0
fi

mkdir -p "$trash"

n=0
while IFS= read -r -d '' dir; do
  mv "$dir" "$trash/$n" 2>/dev/null && n=$((n + 1)) || true
done < <(find "$root/mobile" -type d \( -name build -o -name .dart_tool \) -prune -print0 2>/dev/null)

[ "$n" -gt 0 ] || { rmdir "$trash" 2>/dev/null || true; exit 0; }

# Detach so the unlink outlives the session.
nohup rm -rf "$trash" >/dev/null 2>&1 &

printf '{"systemMessage":"Purged %d build/.dart_tool dirs from %s"}\n' \
  "$n" "$(basename "$root")"
