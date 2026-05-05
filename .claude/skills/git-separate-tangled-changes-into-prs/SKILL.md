---
name: git-separate-tangled-changes-into-prs
description: |
  Separate a messy working tree with multiple tangled features into clean,
  focused PRs. Use when: (1) Working tree has uncommitted changes from
  multiple features mixed together, (2) Need to create a PR for just one
  feature from a mixed working tree, (3) "git stash pop" fails with
  "already exists, no checkout" for untracked files, (4) Pre-commit hooks
  block commits due to unrelated untracked files with errors, (5) Interface
  changes in one feature break consumer files from another feature in the
  same working tree. Covers git stash workflows, branch separation,
  conflict resolution, and pre-commit hook workarounds. Never stack PRs —
  always target main.
author: Claude Code
version: 1.2.0
date: 2026-05-05
---

# Separating Tangled Changes into Clean PRs

## Problem
A working tree accumulates uncommitted changes from multiple features over
time. When you need to create focused PRs, the changes are tangled together
— some files have changes from multiple features, generated files (like
`.mocks.dart`) reflect all features combined, and pre-commit hooks fail on
unrelated WIP code.

## Context / Trigger Conditions
- Working tree has 50+ modified/untracked files spanning multiple features
- `git diff --name-only` shows files from clearly different features
- You need to create a PR for Feature A but Feature B's files cause
  analysis errors
- Pre-commit hooks run `dart analyze` / `eslint` / etc. on ALL files (not
  just staged), so untracked WIP files block commits
- Some files have changes from BOTH features (mixed-change files)

## Solution

### Step 1: Stash Everything Safely
```bash
git stash -u -m "descriptive-name-for-safety"
```
The `-u` flag includes untracked files. This is your safety net.

### Step 2: Create Clean Feature Branch
```bash
git checkout main  # or the appropriate base
git pull
git checkout -b feature/clean-branch
```

### Step 3: Pop Stash and Handle Conflicts
```bash
git stash pop
```

**Common issue**: "already exists, no checkout" — happens when untracked
files from the stash already exist in the working tree. The tracked file
changes still apply, but the stash is preserved (not dropped). This is
safe; the files you need are already there.

**Merge conflicts**: Resolve each one. For files belonging to OTHER
features, take the base version:
```bash
git checkout --theirs path/to/other-feature-file.dart
```

For files belonging to THIS feature, take the stash version or resolve
manually.

### Step 4: Handle Mixed-Change Files
Some files have changes from BOTH features. For these:
1. Restore to the base version: `git checkout main -- path/to/file.dart`
2. Re-apply ONLY your feature's changes manually (usually just import
   changes or a few lines)

### Step 5: Deal with Pre-Commit Hooks That Check All Files
If your pre-commit hook analyzes ALL files (not just staged), untracked
WIP files from other features will block your commit.

**Workaround**: Temporarily move problematic untracked files:
```bash
mkdir -p /tmp/other-features-backup
mv lib/unrelated_feature/ /tmp/other-features-backup/
mv test/unrelated_feature/ /tmp/other-features-backup/
```

Commit, then restore:
```bash
cp -r /tmp/other-features-backup/* .
```

### Step 6: Regenerate Generated Files
If the project uses code generation (Mockito, Riverpod, Freezed, etc.),
restore generated files to base and regenerate:
```bash
git checkout main -- **/*.mocks.dart **/*.g.dart
dart run build_runner build --delete-conflicting-outputs
```

This ensures generated files only reflect YOUR feature's changes.

### Step 7: Fix Interface Break Cascades
When Feature A changes an interface (renames a method, changes parameter
types), consumer files that weren't modified by Feature A will break. The
analyzer catches these. Fix them before committing.

Common pattern:
- Provider state changed `CompleteParameters?` to `Map<String, dynamic>`
- Canvas widget still calls `.colorFilters` on what's now a Map
- Fix: Update the consumer to use the new interface

### Step 8: Do NOT Stack PRs — Combine Dependent Features Into One PR
**Never create a PR that targets another PR's branch instead of `main`.**
Stacked PRs cause real problems in this project: rebases cascade, reviewer
context fragments, merge order becomes load-bearing, CI runs against the
wrong base, and "fix on parent" forces a re-review of the child.

**If Feature B depends on Feature A, ship them as ONE combined PR.**

```bash
# Both features live on a single branch, targeting main
git checkout main && git pull
git checkout -b feature-a-and-b
# ... commit Feature A changes ...
# ... commit Feature B changes (separate commits are fine) ...
gh pr create --base main  # one PR, both features
```

Write the PR description so the two features are clearly delineated —
separate sections, separate test plans. Reviewers can read it as a single
unit, and the merge story is one click. This is the default when changes
are interdependent.

The only time to split is when the features are **truly independent** —
in which case they each get their own PR targeting `main`, in any order.
If you find yourself wanting "B based on A," that's the signal to combine
them, not to stack.

## Verification
1. `git diff main...HEAD --stat` shows only files for YOUR feature
2. `dart analyze` (or equivalent) passes
3. Tests pass
4. Original stash still exists as safety net (if pop failed partially):
   `git stash list`

## Example
Session where model-dedup changes and collaborator/watermark feature
changes were tangled in 140+ modified files. The model-dedup work was
**independent** of the collab/watermark feature, so they split cleanly:

1. Stashed everything from `fix/profile-copy-shares-url`
2. Created `chore/model-deduplication` from main, popped stash
3. Separated model-dedup files, moved 16 untracked feature files to `/tmp/`
4. Committed, pushed, created PR #1411 (target: main)
5. Created `feat/collabs-watermark-inspired-by` from main, popped stash
6. Fixed 3 interface breaks in video_editor_canvas.dart and
   video_metadata_preview_thumbnail.dart
7. Committed, pushed, created PR #1412 (target: main — independent of #1411)

If the two features had been interdependent, they would have shipped as
**one combined PR** — never stacked.

### Alternative: Cherry-Pick Commits + Selective Stash Apply
When changes are split between commits AND stash (not just stash), use this
approach instead:

```bash
# 1. Create branches from origin/main
git branch feature-a origin/main
git branch feature-b origin/main

# 2. Cherry-pick commits to appropriate branches
git checkout feature-a
git cherry-pick <commit-hash-for-feature-a>

# 3. Apply stashed files selectively (see gotchas below)
```

### GOTCHA: Deleted Files in Stash
`git checkout stash@{0} -- <path>` FAILS for files that were DELETED in the
stash — they don't exist in the stash tree. Handle deletions separately:

```bash
# For MODIFIED files — checkout from stash works
git checkout stash@{0} -- path/to/modified_file.dart

# For DELETED files — must use git rm instead
git rm path/to/deleted_file.dart

# Check which are deletions vs modifications first:
git stash show stash@{0} --name-status
# D = deleted (use git rm), M = modified (use checkout)
```

### GOTCHA: Mono-Repo Stash Path Prefixes
When git root is a parent directory but you work in a subdirectory, stash
paths include the subdirectory prefix:

```bash
# Working in: /project/mobile/
# Git root:   /project/
# Stash shows: mobile/lib/file.dart (NOT lib/file.dart)

# Must run checkout from repo root:
cd $(git rev-parse --show-toplevel)
git checkout stash@{0} -- mobile/lib/file.dart
```

### GOTCHA: Cherry-Pick Produces Empty Commit
If a commit was already merged to main via a different PR (different hash),
cherry-pick will produce an empty commit:

```bash
# "The previous cherry-pick is now empty"
git cherry-pick --skip  # Skip it, it's already on main
```

### GOTCHA: Pre-Commit Hooks on Cherry-Picked Branches
When cherry-picking onto branches from `origin/main`, the analyzer may find
pre-existing errors on main unrelated to your changes. Use `--no-verify`
only when you've confirmed the errors aren't yours:

```bash
git commit --no-verify -m "feat: your changes"
```

### Verify Completeness
Compare stash contents against all branch diffs:
```bash
git stash show stash@{0} --name-only | sort > /tmp/stash_files.txt
git diff --name-only origin/main..feature-a
git diff --name-only origin/main..feature-b
# Every stash file should appear in exactly one branch
```

## Notes
- **Always stash with `-u`** to capture untracked files
- **Never force-drop a stash** until you've verified everything is safe
- **Mixed-change files are the hardest part** — identify them early by
  checking which files have changes from multiple features
- **Pre-commit hooks that check all files** (not just staged) are the
  biggest blocker. Know your project's hook behavior before starting.
- **Never stack PRs.** Always target `main`. If features depend on each
  other, combine them into one bigger PR — see Step 8.
- The stash is preserved when `pop` fails on untracked files — don't
  panic, your data is safe
