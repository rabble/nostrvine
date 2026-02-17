---
name: git-worktree-precommit-hook-flutter-failure
description: |
  Fix git pre-commit hook failures in Flutter projects when using git worktrees.
  Use when: (1) Pre-commit hook with `flutter analyze` fails during `git commit`
  but passes when run manually, (2) Hook output shows "Resolving dependencies..."
  then immediately fails with no actual analysis errors, (3) Working in a git
  worktree (created via `git worktree add`). Root cause: git sets GIT_DIR to a
  worktree-style path during hook execution, which breaks `flutter pub get`
  (called internally by `flutter analyze`). Fix: unset GIT_DIR, GIT_INDEX_FILE,
  and GIT_WORK_TREE before flutter/dart commands in the hook.
author: Claude Code
version: 2.0.0
date: 2026-02-08
---

# Git Worktree Pre-Commit Hook Flutter Failure

## Problem
When using `git worktree` for parallel development, pre-commit hooks that run
`flutter analyze` fail during `git commit` even though:
- Running `flutter analyze` directly in the worktree passes with no issues
- Running the pre-commit hook script manually passes
- The hook passes in the main repo checkout

## Root Cause
Git sets `GIT_DIR`, `GIT_INDEX_FILE`, and `GIT_WORK_TREE` environment variables
during hook execution. In a worktree, `GIT_DIR` points to
`.git/worktrees/<name>/` instead of `.git/`. When `flutter analyze` internally
runs `flutter pub get`, pub chokes on this worktree-style `GIT_DIR` path and
fails to resolve dependencies.

The failure is invisible when the hook uses `2>/dev/null` on stderr — you only
see "Resolving dependencies..." then the failure message, with the actual error
suppressed.

## Context / Trigger Conditions
- Using `git worktree add` for parallel branch development
- Pre-commit hook runs `flutter analyze` or `dart analyze`
- Hook output shows "Resolving dependencies..." then immediately fails
- No actual analysis errors are reported
- The hook uses `set -e` (exit on error)
- `2>/dev/null` may hide the actual failure cause

## Diagnosis
Reproduce the exact failure by simulating git's hook environment:

```bash
# This will FAIL (simulates hook execution in worktree)
GIT_DIR=/path/to/main/.git/worktrees/<name> \
  flutter analyze --no-fatal-infos 2>/dev/null

# This will PASS (without git env vars)
flutter analyze --no-fatal-infos
```

## Solution
Add `unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE` to the pre-commit hook
**after** all git commands but **before** any flutter/dart commands.

```bash
#!/bin/bash
set -e

cd "$(git rev-parse --show-toplevel)/mobile"

# Git operations (these NEED the git env vars)
STAGED_DART_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.dart$' || true)

if [ -z "$STAGED_DART_FILES" ]; then
    echo "No Dart files staged, skipping checks"
    exit 0
fi

# Unset git env vars BEFORE running flutter/dart commands.
# Git sets these during hook execution, and flutter pub get
# (called internally by flutter analyze) chokes on worktree-style
# GIT_DIR paths.
unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE

# Now flutter/dart commands work in both main repo and worktrees
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-fatal-infos
```

Key points:
- The `unset` MUST come after `git diff --cached` (which needs `GIT_INDEX_FILE`)
- The `unset` MUST come before `flutter analyze` and `dart format`
- Remove `2>/dev/null` from `flutter analyze` so errors are visible

## Verification
1. Make a change in a git worktree
2. Stage the file: `git add <file>`
3. Commit: `git commit -m "test"` — hook should pass
4. Verify the same hook still works in the main repo checkout

## Notes
- This affects any tool that internally runs `pub get` or interacts with git
  during hook execution (not just `flutter analyze`)
- `dart format` may also be affected in some configurations
- The `git rev-parse --show-toplevel` call at the top of the hook works
  correctly with `GIT_DIR` set — it resolves to the worktree root
- Only unset the vars when you're done with git operations
