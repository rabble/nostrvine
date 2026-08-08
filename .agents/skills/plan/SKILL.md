---
name: plan
description: |
  Investigate a GitHub issue and produce a structured implementation plan.
  Fetches issue details, explores the codebase, identifies affected layers
  (UI, BLoC, Repository, Client), and outputs a step-by-step plan with
  files to modify, testing strategy, and risk assessment. Works for bugs,
  features, and tasks. Invoke with /plan.
author: Claude Code
version: 1.0.0
date: 2026-02-09
user_invocable: true
invocation_hint: /plan
arguments: |
  Required: GitHub issue number or URL
  Example: /plan 142
  Example: /plan #142
  Example: /plan https://github.com/divinevideo/divine-mobile/issues/142

  If no argument is provided, ask the user which issue to investigate.
---

# Issue Investigation & Planning Skill

## Purpose

Investigate a GitHub issue thoroughly and produce a structured, actionable
implementation plan. The plan follows the project's layered architecture
(UI -> BLoC -> Repository -> Client) and includes files to modify,
implementation steps, testing strategy, and risk assessment.

## Workflow

### Phase 1: Fetch Issue

Retrieve the full issue context using `gh` CLI and GraphQL.

```bash
# Get issue details
gh issue view <number> --json title,body,comments,labels,state,assignees

# Get issue type, hierarchy, and sub-issues
gh api graphql -f query='{ repository(owner: "divinevideo", name: "divine-mobile") {
  issue(number: <NUMBER>) {
    id
    title
    body
    issueType { id name }
    subIssues(first: 20) { nodes { number title state } }
    parentIssue { number title }
  }
} }'
```

Determine the issue type from:
- Title prefix: `fix:` = Bug, `feat:` = Feature, `task:` = Task
- GraphQL `issueType` field
- Labels (e.g., `bug` label)

Extract key information:
- **Bug**: Steps to reproduce, actual vs expected result, environment, evidence
- **Feature**: Requirements, acceptance criteria, user stories
- **Task**: Description, scope, implementation notes

### Phase 2: Explore Codebase

Search the codebase to understand the relevant code. Approach varies by type.

#### For Bugs
1. Search for keywords from the bug description (error messages, screen names, widget names) using `Grep`
2. Identify the screen/page where the bug manifests using `Glob` on `lib/screens/` and `lib/widgets/`
3. Trace the code path from UI through BLoC to Repository to Client
4. Check for related tests using `Glob` on `test/`
5. If Nostr-related, use `mcp__nostr__read_kind` or `mcp__nostr__read_nip` for protocol context

#### For Features
1. Search for similar existing features using `Grep` and `Glob`
2. Identify which architectural layers are needed (new BLoC? New repository? New package?)
3. Check if related models/repositories already exist in `mobile/packages/`
4. Look at the router (`mobile/lib/router/`) for navigation integration
5. If Nostr-related, use `mcp__nostr__*` tools to understand relevant NIPs and event kinds

#### For Tasks
1. Search for the specific code area mentioned in the task using `Grep`
2. Understand the current implementation state
3. Check for existing tests that need updating
4. Identify related files that might be affected

### Phase 3: Analyze

#### For Bugs
- Identify the root cause by reading the relevant source files
- Determine which layer(s) contain the bug (UI? BLoC? Repository? Client?)
- Assess regression risk (what else could break?)
- Check if existing tests should have caught this

#### For Features
- Determine which layers need new code vs modifications
- Design the data flow: Client -> Repository -> BLoC -> UI
- Identify new models, events, states needed
- Consider integration with existing features (router, theme, existing BLoCs)
- Assess if any new packages are needed in `mobile/packages/`

#### For Tasks
- Scope the change precisely
- Identify all files that need modification
- Determine if the task has cascading effects

### Phase 4: Plan

Construct the implementation plan following the project's layered architecture.
Always order implementation steps bottom-up:

1. Data layer changes (Client packages in `mobile/packages/`)
2. Repository layer changes (Repository packages in `mobile/packages/`)
3. Business logic changes (BLoCs in `mobile/lib/blocs/`)
4. Presentation layer changes (Screens/Widgets in `mobile/lib/screens/` or `mobile/lib/widgets/`)
5. Router changes (if navigation is affected)
6. Test plan (mirroring the implementation layers)

### Phase 5: Output

Present the plan using the output template below.

## Output Template

```markdown
## Plan: [Issue Title] (#[number])

**Type**: Bug | Feature | Task
**Issue**: [URL]
**Complexity**: Low | Medium | High

---

### Issue Summary
[1-2 sentence summary in your own words after investigation]

### [Bug Only] Root Cause
- **Layer**: [UI | BLoC | Repository | Client]
- **File**: [exact file path with line numbers]
- **Cause**: [clear explanation of why this happens]
- **Evidence**: [code snippet or logic trace]

### [Feature Only] Architecture Design
- **New packages needed**: [list or "None"]
- **Layers affected**: [which of UI, BLoC, Repository, Client]
- **Data flow**: [Client -> Repository -> BLoC -> UI description]
- **Nostr events**: [relevant kinds/NIPs if applicable]

### Affected Files

| File | Action | Description |
|------|--------|-------------|
| `path/to/file.dart` | Modify / Create / Delete | What changes |

### Implementation Steps

Steps ordered bottom-up (data layer first, UI last):

1. **[Layer]: [Brief description]**
   - File: `path/to/file.dart`
   - Changes: [specific changes]
   - Why: [rationale]

2. ...

### Testing Strategy

| Layer | Test File | What to Test |
|-------|-----------|-------------|
| [Layer] | `test/path/to/test.dart` | [specific test cases] |

### Risks and Considerations
- [Risk 1 and mitigation]
- [Risk 2 and mitigation]

```

## Tool Reference

| Need | Tool | Example |
|------|------|---------|
| Fetch issue | `gh issue view` | `gh issue view 142 --json title,body,comments,labels` |
| Issue hierarchy | `gh api graphql` | Sub-issues, parent issues, issue type |
| Find files by name | `Glob` | `Glob("**/*video_feed*")` |
| Search code content | `Grep` | `Grep("VideoFeedBloc")` |
| Read file details | `Read` | `Read("mobile/lib/blocs/video_feed/video_feed_bloc.dart")` |
| Check code health | `mcp__dart__analyze_files` | Analyze affected packages |
| Find Dart symbols | `mcp__dart__resolve_workspace_symbol` | Look up class/method names |
| Nostr protocol | `mcp__nostr__read_nip` | Check NIP specifications |
| Nostr event kinds | `mcp__nostr__read_kind` | Understand event structure |

## Complexity Guidelines

| Complexity | Criteria |
|-----------|----------|
| **Low** | Single layer, 1-3 files, no new models or packages |
| **Medium** | 2-3 layers, 4-10 files, may need new BLoC events/states |
| **High** | All layers, 10+ files, new packages, new models, Nostr protocol changes |

## Architecture Reference

- **Layer order**: UI -> BLoC -> Repository -> Client
- **Implementation order**: Bottom-up (Client first, UI last)
- **Packages**: `mobile/packages/`
- **BLoCs**: `mobile/lib/blocs/`
- **Screens**: `mobile/lib/screens/`
- **Widgets**: `mobile/lib/widgets/`
- **Router**: `mobile/lib/router/`
- **Tests mirror**: `mobile/test/` mirrors `mobile/lib/`
- **State management**: BLoC for new features, Riverpod for legacy
- **Theme**: Dark mode only, use `VineTheme` constants
- **Nostr IDs**: Never truncate, always full 64-char hex
