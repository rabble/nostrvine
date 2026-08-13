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

# Only meaningful in a divine-mobile checkout.
[ -f "$root/mobile/pubspec.yaml" ] || exit 0

# A linked worktree's git dir lives at <repo>/.git/worktrees/<name>; the main
# checkout's does not. Skip the main checkout.
gitdir="$(git -C "$root" rev-parse --absolute-git-dir 2>/dev/null || true)"
case "$gitdir" in
  */.git/worktrees/*) ;;
  *) exit 0 ;;
esac

# Stage removals under one directory, then delete detached. Renaming within a
# filesystem is instant, so the session exits immediately instead of waiting
# on tens of GB of unlink; a killed background rm just leaves the staging dir
# for the next run to collect.
trash="$root/.claude-purge"
rm -rf "$trash" 2>/dev/null || true
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
