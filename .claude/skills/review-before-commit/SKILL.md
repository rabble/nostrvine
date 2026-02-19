---
name: review-before-commit
description: |
  Review all uncommitted changes before pushing. Checks for dead code,
  stale comments, CLAUDE.md rule violations, unused imports, and
  inconsistencies introduced during the current session.
  Invoke with /review-before-commit.
author: Claude Code
version: 1.0.0
date: 2026-02-10
user_invocable: true
invocation_hint: /review-before-commit
arguments: |
  Optional: Scope the review to specific paths
  Example: /review-before-commit
  Example: /review-before-commit lib/blocs/hashtag_feed/
---

# Review Skill

## Purpose
Final code review of all uncommitted changes before pushing. Catches issues
that are easy to introduce during iterative development: stale comments
referencing removed code, dead code, rule violations, and inconsistencies.

## How to Review

### Step 1: Identify changed files

Run `git diff --name-only` and `git diff --cached --name-only` to get the full
list of modified files (staged + unstaged). If the user provided a path argument,
filter to only files under that path.

### Step 2: Read all changed files

Read every changed file in full. For each file, check the items below.

### Step 3: Run checks

For each changed file, check for:

#### Dead Code
- Unused imports (import not referenced anywhere in the file)
- Unused private fields, methods, or getters
- Unreachable code after early returns
- Commented-out code blocks (should be deleted, not commented)

#### Stale References
- Comments or doc strings referencing methods, classes, or variables that no
  longer exist in the codebase (use Grep to verify references are still valid)
- ABOUTME comments that no longer accurately describe the file
- TODO comments for work that was already completed in this session

#### CLAUDE.md Rule Violations
Read and apply ALL rules from `.claude/CLAUDE.md` and `.claude/rules/`. Do not
hardcode specific rules here — always check the source of truth in those files.

#### Test Consistency
- If production code changed, verify corresponding tests exist and still match
- Check for test assertions that reference removed fields or methods
- Verify mock setups match current method signatures

### Step 4: Run analyzer and tests

1. Run `mcp__dart__analyze_files` on all changed files
2. Run `mcp__dart__run_tests` on all changed test files
3. Report any failures

### Step 5: Report findings

Present findings grouped by severity:

```
## Review Summary

### Must Fix
- [file.dart:42](path/to/file.dart#L42) - Description of the issue

### Should Fix
- [file.dart:15](path/to/file.dart#L15) - Description of the issue

### Nitpick
- [file.dart:7](path/to/file.dart#L7) - Description of the issue

### All Clear
If no issues found, confirm: "No issues found. Ready to push."
```

**Severity definitions:**
- **Must Fix**: Will cause bugs, test failures, or CI failures
- **Should Fix**: Violates project rules, dead code, stale comments
- **Nitpick**: Style preferences, minor improvements

After reporting, fix all "Must Fix" and "Should Fix" items automatically.
Ask the user before fixing "Nitpick" items.
