---
name: github-issue
description: |
  Create well-structured GitHub issues following the Epic > Feature > Task/Bug
  hierarchy. Uses GitHub issue types (not labels) and relationships to connect
  related issues. Invoke with /github-issue.
author: Claude Code
version: 1.1.0
date: 2026-02-09
user_invocable: true
invocation_hint: /github-issue
arguments: |
  Required: Description of the issue to create
  Example: /github-issue profile stats text wrapping bug
  Example: /github-issue add video download feature

  If no argument is provided, ask the user what issue they want to create.
---

# GitHub Issue Creation Skill

## Purpose
Help create well-structured GitHub issues that follow the project's hierarchy,
conventions, and existing templates from `.github/ISSUE_TEMPLATE/`.

## Issue Hierarchy

```
Epic (large initiative, multiple features)
  └── Feature (user-facing capability, multiple tasks)
        └── Task (single unit of work)
        └── Bug (defect to fix)
```

### When to Use Each Type

| Type | Title Prefix | Use When |
|------|--------------|----------|
| **Epic** | `epic: ` | Large initiative spanning weeks/months |
| **Feature** | `feat: ` | New user-facing capability |
| **Task** | `task: ` | Single unit of implementation work |
| **Bug** | `fix: ` | Something is broken/not working as expected |

## Issue Templates

### Bug Template (matches `.github/ISSUE_TEMPLATE/bug_report.yaml`)

**Title format:** `fix: <description>`

```markdown
## Summary
[One sentence about what's broken]

## Environment
- App version: [e.g., 1.2.3]
- Device: [e.g., iPhone 14 Pro, iOS 17.1]
- Network: [WiFi / Cellular]

## Steps to Reproduce
1. Go to '...'
2. Click on '...'
3. See error

## Actual Result
[What actually happened]

## Expected Result
[What you expected to happen]

## Regression?
[Yes / No / Unknown - Did this work in a previous version?]

## Evidence
[Screenshots, screen recordings, logs, crash reports]
```

### Feature Template (matches `.github/ISSUE_TEMPLATE/feature_request.yaml`)

**Title format:** `feat: <description>`

```markdown
## What would you like?
[Describe the feature or improvement]

## How would this be useful for you?
[What problem does this solve or what does it make easier?]

## When would you use this?
[Describe a situation where you'd need this feature]

## Anything else?
[Screenshots, mockups, examples from other apps]
```

### Task Template

**Title format:** `task: <description>`

```markdown
## Description
[Clear description of what needs to be done]

## Context
[Why this task is needed]

## Implementation Notes
[Technical approach, files to modify, considerations]

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Testing
[How to verify this task is complete]
```

### Epic Template

**Title format:** `epic: <description>`

```markdown
## Overview
[High-level description of the initiative]

## Goals
- [ ] Goal 1
- [ ] Goal 2

## Features
- [ ] #XXX Feature name
- [ ] #YYY Feature name

## Success Criteria
[How we know this epic is complete]

## Notes
[Additional context, constraints, or considerations]
```

## Relationships

Use GitHub's sub-issue API (NOT text like "Part of #123" in the body):

| Relationship | How |
|--------------|-----|
| Parent/Child | `addSubIssue` GraphQL mutation |
| Related | `Related to #789` in body text |
| Blocks | `Blocks #101` in body text |
| Blocked by | `Blocked by #102` in body text |

## Workflow

1. **Gather Information**: Ask clarifying questions to understand the issue
2. **Determine Type**: Based on scope, choose Epic/Feature/Task/Bug
3. **Search for Parent**: Search for related Features/Epics and ask user which to link
4. **Draft Issue**: Use the appropriate template matching `.github/ISSUE_TEMPLATE/`
5. **Review with User**: Show the draft before creating
6. **Create Issue**: 3-step process below

## Creating Issues (3-step process)

### Step 1: Create the issue
```bash
gh issue create \
  --title "fix:|feat:|task:|epic: Description" \
  --body "..." \
  --assignee NotThatKindOfDrLiz
```

### Step 2: Set issue type via GraphQL
Available types and their IDs (repo: divinevideo/divine-mobile):
- **Task**: `IT_kwDODpf9Q84ByDOD`
- **Bug**: `IT_kwDODpf9Q84ByDOE`
- **Feature**: `IT_kwDODpf9Q84ByDOF`

```bash
# Get the issue node ID
gh api graphql -f query='{ repository(owner: "divinevideo", name: "divine-mobile") {
  issue(number: ISSUE_NUMBER) { id }
} }'

# Set the type
gh api graphql -f query='mutation { updateIssueIssueType(input: {
  issueId: "ISSUE_NODE_ID",
  issueTypeId: "TYPE_ID"
}) { issue { id } } }'
```

### Step 3: Set parent relationship via GraphQL
```bash
# Get parent issue node ID
gh api graphql -f query='{ repository(owner: "divinevideo", name: "divine-mobile") {
  issue(number: PARENT_NUMBER) { id }
} }'

# Add as sub-issue
gh api graphql -f query='mutation { addSubIssue(input: {
  issueId: "PARENT_NODE_ID",
  subIssueId: "CHILD_NODE_ID"
}) { issue { id } subIssue { id } } }'
```

### Search for Parent Issues
Before creating a Task or Bug, search for related Features/Epics:
```bash
gh issue list --search "related keywords" --limit 10
```

## Best Practices

1. **Use correct title prefix**: `fix:`, `feat:`, `task:`, `epic:`

2. **One issue, one concern**: Don't combine multiple bugs or features

3. **Use sub-issue API for hierarchy**: Never use "Part of #XXX" text, use GraphQL `addSubIssue`

4. **Include context**: Explain why, not just what

5. **Be specific**: Include file paths, error messages, steps to reproduce

6. **Match existing templates**: Follow the structure from `.github/ISSUE_TEMPLATE/`

## Example: Creating a Bug

```bash
gh issue create \
  --title "fix: Profile stats labels wrap incorrectly on small screens" \
  --body "$(cat <<'EOF'
## Summary
Profile stats labels ("Followers", "Following") wrap to multiple lines, splitting words mid-word.

## Environment
- App version: Latest
- Device: Small screen devices
- Network: N/A

## Steps to Reproduce
1. Open profile screen on a small device or narrow width
2. Look at the stats row (Videos, Followers, Following)
3. See labels wrapping incorrectly

## Actual Result
Labels wrap mid-word:
- "Followers" becomes "Follower" + "s"
- "Following" becomes "Followin" + "g"

## Expected Result
Labels should remain on a single line, or truncate with ellipsis if needed.

## Regression?
Unknown

## Evidence
<!-- Screenshot to be attached after creation -->
EOF
)"
```
