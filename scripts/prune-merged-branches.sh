#!/usr/bin/env bash
# ABOUTME: Reports which local branches and worktrees look safe to prune.
# ABOUTME: Report-only until deletion has a separately reviewed implementation.
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
# So the useful signal in a squash-merge repo is GitHub reporting a same-repo PR
# to main with this head ref merged. Everything else is KEEP.
#
# The bias is deliberate. A false KEEP costs disk. A false DELETE costs work
# that exists nowhere else — an unpushed branch has no backup.
#
# Usage:
#   bash scripts/prune-merged-branches.sh
#   bash scripts/prune-merged-branches.sh --help
#
# Requires: gh (authenticated), git, perl. Run from the repo root.

set -euo pipefail

usage() {
  sed -n '/^# Usage:/,/^# Requires:/s/^# \{0,1\}//p' "$0"
}

for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

GH="${GH:-gh}"
BASE="${BASE:-origin/main}"
REPO="${REPO:-${GITHUB_REPOSITORY:-divinevideo/divine-mobile}}"
MERGED_PR_LIMIT="${MERGED_PR_LIMIT:-100000}"

command -v "$GH" >/dev/null || { echo "$GH not found" >&2; exit 2; }
git rev-parse --git-dir >/dev/null || exit 2

echo "Fetching origin..."
git fetch origin --prune --quiet
git rev-parse --verify --quiet "$BASE" >/dev/null || {
  echo "$BASE not found" >&2; exit 2
}

# Shallow is fine for the signals used here: the GitHub lookups need no local
# history, and the worktree checks inspect only the current checkout state.
if [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then
  echo "Note: shallow repository. Classification is unaffected."
fi

echo "Loading merged PR head refs from GitHub..."
MERGED_REFS="$(mktemp)"
WORKTREE_FIELDS="$(mktemp)"
trap 'rm -f "$MERGED_REFS" "$WORKTREE_FIELDS"' EXIT

"$GH" pr list --state merged --limit "$MERGED_PR_LIMIT" \
  --json headRefName,isCrossRepository,baseRefName \
  --jq '.[] | select(.isCrossRepository == false and .baseRefName == "main") | .headRefName' \
  | sort -u > "$MERGED_REFS"
echo "  $(wc -l < "$MERGED_REFS" | tr -d ' ') merged head refs known"

git worktree list --porcelain -z > "$WORKTREE_FIELDS"

worktree_for() {
  WANT="refs/heads/$1" perl -0ne '
    chomp;
    if (/^worktree (.*)\z/s) { $path = $1; next }
    if (/^branch (.*)\z/s && $1 eq $ENV{"WANT"}) { print $path; exit }
  ' "$WORKTREE_FIELDS"
}

commit_exists_on_github() {
  "$GH" api -X GET "repos/$REPO/commits/$1" >/dev/null 2>&1
}

CURRENT="$(git rev-parse --abbrev-ref HEAD)"

printf '\n%-14s %-50s %s\n' "VERDICT" "BRANCH" "WORKTREE"
printf '%s\n' "--------------------------------------------------------------------------------"

merged=0; keep=0
while IFS= read -r branch; do
  case "$branch" in main|master) continue ;; esac
  [ "$branch" = "$CURRENT" ] && continue

  wt="$(worktree_for "$branch")"
  tip="$(git rev-parse "$branch")"

  if grep -qxF -- "$branch" "$MERGED_REFS"; then
    verdict="MERGED-PR"
  else
    verdict="KEEP"
  fi

  # Vetoes are applied even to MERGED-PR branches.

  # Veto 1: the local tip must exist in GitHub's repository object database.
  # This catches unpushed work and branch-name reuse after an older PR merged.
  if [ "$verdict" = "MERGED-PR" ]; then
    if ! commit_exists_on_github "$tip"; then
      verdict="KEEP-LOCAL"
    fi
  fi

  # Veto 2: uncommitted or ignored work in the branch's worktree exists in no
  # commit anywhere, merged PR or not.
  if [ "$verdict" = "MERGED-PR" ] && [ -n "$wt" ] && [ -d "$wt" ]; then
    if [ -n "$(git -C "$wt" status --porcelain --ignored=matching 2>/dev/null)" ]; then
      verdict="KEEP-DIRTY"
    fi
  fi

  printf '%-14s %-50s %s\n' "$verdict" "$branch" "${wt:-—}"
  if [ "$verdict" = "MERGED-PR" ]; then
    merged=$((merged + 1))
  else
    keep=$((keep + 1))
  fi
done < <(git for-each-ref --format='%(refname:short)' refs/heads/ | sort)

printf '\n%s likely prunable (merged same-repo PR to main, local tip on GitHub, clean) / %s kept.\n' "$merged" "$keep"
echo
echo "Report only. This script does not delete branches or worktrees."
echo "KEEP includes branches with no matching merged same-repo PR to main,"
echo "branches whose local tip is not on GitHub, and branches with dirty or"
echo "ignored worktree files. Review kept branches by hand."
