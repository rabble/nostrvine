#!/usr/bin/env bash
# ABOUTME: Reports which local branches and worktrees are safe to prune.
# ABOUTME: Report-only by default; deletion is a separate explicit opt-in.
#
# Why the obvious approaches are wrong here
# -----------------------------------------
# 1. `git branch --merged main` reports 5 of 1185 branches. This repo
#    squash-merges, and a squash rewrites the commit, so a merged branch never
#    becomes an ancestor of main. Ancestry is not the signal.
#
# 2. "Empty diff against main" does not work either. `git diff main <branch>`
#    is symmetric: a branch that merged months ago still differs from today's
#    main by everything that landed since. It reports 2445 changed files for a
#    long-merged branch here.
#
# 3. Name matching destroys work. Deleting everything matching "7606" took out
#    `fix/7606-semantic-tokens` — unpushed local work on a parallel attempt.
#
# So there is exactly one trustworthy signal in a squash-merge repo: GitHub
# says a PR with this head ref merged. Everything else is KEEP.
#
# The bias is deliberate. A false KEEP costs disk. A false DELETE costs work
# that exists nowhere else — an unpushed branch has no backup.
#
# Usage:
#   bash prune-stale-worktrees.sh                  # report only (default)
#   bash prune-stale-worktrees.sh --execute        # delete, with confirmation
#   bash prune-stale-worktrees.sh --execute --yes  # no confirmation
#
# Requires: gh (authenticated), git. Run from the repo root.

set -euo pipefail

EXECUTE=0
ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --execute) EXECUTE=1 ;;
    --yes) ASSUME_YES=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

command -v gh >/dev/null || { echo "gh not found" >&2; exit 2; }
git rev-parse --git-dir >/dev/null || exit 2

BASE=origin/main
echo "Fetching origin..."
git fetch origin --prune --quiet
git rev-parse --verify --quiet "$BASE" >/dev/null || {
  echo "$BASE not found" >&2; exit 2
}

# Shallow is fine for the signals used here: the GitHub lookup needs no local
# history, and the unpushed check compares a branch tip against its own remote
# tracking ref. Only note it, because `git branch -d`'s built-in safety check
# does need ancestry and will refuse more often than it strictly must.
if [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then
  echo "Note: shallow repository. Classification is unaffected, but git's own"
  echo "      -d safety check may refuse some deletions. That is safe."
fi

echo "Loading merged PR head refs from GitHub..."
MERGED_REFS="$(mktemp)"
DELETABLE="$(mktemp)"
trap 'rm -f "$MERGED_REFS" "$DELETABLE"' EXIT

gh pr list --state merged --limit 2000 --json headRefName \
  --jq '.[].headRefName' | sort -u > "$MERGED_REFS"
echo "  $(wc -l < "$MERGED_REFS" | tr -d ' ') merged head refs known"

worktree_for() {
  git worktree list --porcelain \
    | awk -v want="refs/heads/$1" '
        /^worktree /  { path = substr($0, 10) }
        /^branch /    { if (substr($0, 8) == want) print path }
      '
}

CURRENT="$(git rev-parse --abbrev-ref HEAD)"

printf '\n%-14s %-50s %s\n' "VERDICT" "BRANCH" "WORKTREE"
printf '%s\n' "--------------------------------------------------------------------------------"

merged=0; keep=0
while IFS= read -r branch; do
  case "$branch" in main|master) continue ;; esac
  [ "$branch" = "$CURRENT" ] && continue

  wt="$(worktree_for "$branch")"

  if grep -qxF "$branch" "$MERGED_REFS"; then
    verdict="MERGED-PR"
  else
    verdict="KEEP"
  fi

  # Two independent vetoes, applied even to MERGED-PR branches.

  # Veto 1: uncommitted work in the branch's worktree exists in no commit
  # anywhere, merged PR or not.
  if [ "$verdict" = "MERGED-PR" ] && [ -n "$wt" ] && [ -d "$wt" ]; then
    if [ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]; then
      verdict="KEEP-DIRTY"
    fi
  fi

  # Veto 2: local commits the remote tracking ref does not have. Covers the
  # "merged, then someone kept working on the branch" case.
  if [ "$verdict" = "MERGED-PR" ]; then
    upstream="$(git rev-parse --abbrev-ref --symbolic-full-name \
      "$branch@{upstream}" 2>/dev/null || true)"
    if [ -n "$upstream" ]; then
      ahead="$(git rev-list --count "$upstream..$branch" 2>/dev/null || echo 0)"
      [ "$ahead" -gt 0 ] && verdict="KEEP-AHEAD"
    fi
  fi

  printf '%-14s %-50s %s\n' "$verdict" "$branch" "${wt:-—}"
  if [ "$verdict" = "MERGED-PR" ]; then
    merged=$((merged + 1))
    printf '%s\t%s\n' "$branch" "$wt" >> "$DELETABLE"
  else
    keep=$((keep + 1))
  fi
done < <(git for-each-ref --format='%(refname:short)' refs/heads/ | sort)

printf '\n%s deletable (merged PR, clean, not ahead) / %s kept.\n' "$merged" "$keep"
echo
echo "KEEP includes every branch with no merged PR — which is where unpushed"
echo "local work lives. Review those by hand; this script will never touch them."

if [ "$EXECUTE" -ne 1 ]; then
  echo
  echo "Report only. Re-run with --execute to delete the MERGED-PR rows."
  exit 0
fi

[ "$merged" -eq 0 ] && exit 0

if [ "$ASSUME_YES" -ne 1 ]; then
  printf '\nDelete %s branches and their worktrees? [y/N] ' "$merged"
  read -r reply
  case "$reply" in [yY]*) ;; *) echo "Aborted."; exit 0 ;; esac
fi

while IFS=$'\t' read -r branch wt; do
  if [ -n "$wt" ] && [ -d "$wt" ]; then
    git worktree remove "$wt" || {
      echo "  worktree busy: $wt — skipping $branch"; continue
    }
  fi
  # -d, never -D. Git's own unmerged check is a second safety net under the
  # classification above; when it refuses, that disagreement is worth a look.
  git branch -d "$branch" 2>/dev/null \
    || echo "  git refused to delete $branch — kept, review by hand"
done < "$DELETABLE"

git worktree prune
echo "Done."
