---
name: pr-summary
description: |
  Generate a PR description following the project's pull_request_template.md.
  Analyzes all commits on the current branch vs main, summarizes changes,
  and outputs a ready-to-paste PR body. Invoke with /pr-summary.
author: Claude Code
version: 1.0.0
date: 2026-02-10
user_invocable: true
invocation_hint: /pr-summary
arguments: |
  Optional: GitHub issue number to link
  Example: /pr-summary
  Example: /pr-summary 1461
  Example: /pr-summary #1461

  If no argument is provided, attempt to detect the issue from branch name or commit messages.
---

# PR Summary Skill

## Purpose

Generate a pull request description that follows the project's
`.github/pull_request_template.md` format. Analyzes all changes on the
current branch compared to main and produces a concise, ready-to-paste
PR body.

## Workflow

### Step 1: Gather Context

```bash
# Current branch name
git branch --show-current

# Commits on this branch vs main
git log main..HEAD --oneline

# Files changed with stats
git diff main...HEAD --stat

# Full diff for analysis
git diff main...HEAD
```

### Step 2: Detect Issue Number

Look for the related issue number from (in priority order):
1. Argument passed to the skill
2. Branch name (e.g., `fix/explore-hashtags-empty-view` -> search issues)
3. Commit messages (e.g., `Closes #1461`)

### Step 3: Analyze Changes

Read the diff and identify:
- What the change does (1-3 sentences max)
- Which type of change it is (bug fix, feature, refactor, etc.)
- Key architectural decisions (layers affected, new files, patterns used)

### Step 4: Output

Output the PR body as a **raw markdown code block** so the user can copy-paste
it directly into the GitHub PR description field.

Wrap the entire output in a fenced code block with the `markdown` language tag:

````
```markdown
<the PR body here>
```
````

## Output Template

The content inside the code block must follow this structure exactly:

```
## Description

[1-3 sentence summary of what changed and why]

**Related Issue:** Closes #[number]

## Type of Change

- [ ] New feature (non-breaking change which adds functionality)
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Code refactor
- [ ] Build configuration change
- [ ] Documentation
- [ ] Chore
```

Only check the applicable type (`[x]`). Keep the description short and focused
on the "what" and "why", not implementation details. Reviewers can read
the diff for the "how".

## Rules

- **Output as code block**: Always wrap the full PR body in a ` ```markdown ` fenced code block so the user can copy-paste directly into GitHub.
- **Be concise**: 1-3 sentences for description. No implementation details.
- **Follow the template exactly**: Use the checkboxes from `pull_request_template.md`.
- **Single type**: Only check one type of change unless it genuinely spans multiple.
- **Link the issue**: Always include `Closes #N` if an issue is known.
- **No emoji in description**: The template already has emoji in the type checkboxes.
- **No file lists or tables**: The diff is available for reviewers. Don't duplicate it.
