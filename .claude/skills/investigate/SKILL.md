---
name: investigate
description: |
  Deep, structured root-cause analysis for complex bugs and issues.
  Uses a 7-phase investigation methodology with confidence scoring,
  layer-specific analysis strategies, and structured output.
  For routine issue planning use /plan instead. Use /investigate when
  a bug is complex, cross-layer, or requires deep root-cause analysis.
  Invoke with /investigate.
author: Claude Code
version: 1.0.0
date: 2026-04-02
user_invocable: true
invocation_hint: /investigate
arguments: |
  Required: GitHub issue number/URL, or a bug description
  Example: /investigate 142
  Example: /investigate https://github.com/divinevideo/divine-mobile/issues/142
  Example: /investigate "video playback freezes after backgrounding on Android"

  If no argument is provided, ask the user what to investigate.
---

# Deep Issue Investigation Skill

## Purpose

Produce a definitive, structured root-cause analysis that leads to a guaranteed
resolution path. This skill goes deeper than `/plan` — use it for complex bugs,
cross-layer issues, regressions, performance problems, or any issue where the
root cause is not obvious.

## Core Behavior Rules

1. **Morgan's Law** — AI analysis might be wrong. Acknowledge uncertainty.
   Rate confidence. Never present speculation as fact.

2. **Guardrails over guessing** — Treat your own analysis the way you would
   treat user input: validate it, verify it against source code, and flag
   when uncertain. If you cannot trace a cause to a specific code path, say so.

3. **Ask before assuming** — Before diving in, identify what information is
   missing and ask clarifying questions. Do not fill gaps with assumptions.

4. **Separation of concerns** — Use LLM reasoning for creative analysis
   (hypotheses, pattern recognition). Defer to tools and code for deterministic
   tasks (version checks, running commands). Label each clearly.

5. **Narrow your focus** — Do not analyze every layer upfront. Classify first,
   then deep-dive only into the relevant layer(s).

6. **Confidence scoring** — Rate every hypothesis and conclusion on 0.0-1.0.

7. **Verify every claim** — Never trust the reporter's diagnosis without
   tracing the code.

8. **Always provide a workaround** — Even if ugly, give something shippable today.

## Workflow

### Phase 0: Pre-Analysis Checkpoint

Before doing any analysis, output a brief intake summary:

1. State what you understand the issue to be (2-3 sentences)
2. List what information is present vs missing
3. State which layer(s) you suspect and why (with confidence score)
4. Ask: "Do you want me to proceed with this understanding, or should I adjust?"

Only proceed after user confirms (or skip if user says "proceed without confirmation").

### Phase 1: Issue Intake & Classification

1. **Parse the issue completely** — extract title, labels, environment,
   reproduction steps, stack traces, screenshots, affected platforms.

2. **Classify the issue type** (may be multiple):
   - Bug, Regression, Crash, Performance, Build Failure
   - Pub/Dependency, Platform Integration, UI/Rendering
   - Testing, State Management

3. **Identify the suspect layer(s)** — only flag layers with evidence:

   | Layer | Scope |
   |-------|-------|
   | Presentation | Widgets, screens, animations, gestures |
   | Business Logic | BLoCs, Cubits, event handling |
   | Repository | Data composition, caching, fallback logic |
   | Client/Data | API calls, relay connections, local storage |
   | Nostr Protocol | Event kinds, NIPs, relay behavior |
   | Flutter Framework | Framework-level rendering, lifecycle |
   | Platform | Android/iOS native, permissions, lifecycle |

4. **Assess reproducibility** (grade A-F):
   - **A**: Minimal standalone repro, reproduces 100%
   - **B**: Repro project but not minimal, reproduces reliably
   - **C**: Steps described clearly, no repro code, reproducible
   - **D**: Intermittent, timing/race condition suspected
   - **E**: Environment-specific
   - **F**: Insufficient info

### Phase 2: Environment Deep Dive

Skip if clearly code-level. Otherwise check:

- Flutter/Dart SDK versions
- Device/OS versions
- Renderer (Skia vs Impeller)
- Build mode (debug JIT vs release AOT)
- Relevant package versions from pubspec.lock

### Phase 3: Reproduction Engineering

- Build or refine a minimal reproduction
- Document: setup commands, run command, expected vs actual, frequency
- For this project: check if it reproduces against the local Docker stack
  (`mise run local_up`) when relay/API behavior is involved

### Phase 4: Layer-Specific Root-Cause Analysis

Apply ONLY the strategy matching the suspect layer(s):

#### Presentation Layer
- Trace widget build -> layout -> paint
- Check State lifecycle (initState -> dispose)
- Look for: setState after dispose, missing keys, stale context
- Check BlocBuilder/BlocListener wiring

#### Business Logic (BLoC/Cubit)
- Check event transformer (concurrent vs sequential vs droppable)
- Look for: race conditions, missing state emissions, stale subscriptions
- Verify state does not contain error strings (use status enum)
- Check for mutable instance variables on the BLoC class

#### Repository Layer
- Check data source composition and fallback logic
- Verify caching behavior
- Look for: missing error handling, stale cache, wrong source priority

#### Client/Data Layer
- Check API/relay request construction
- Verify serialization/deserialization
- Look for: missing fields, wrong types, timeout handling

#### Nostr Protocol
- Verify event kind structure against NIPs using `mcp__nostr__read_kind`
  and `mcp__nostr__read_nip`
- Check tag structure, signature verification
- Look for: truncated IDs (project-wide rule: never truncate)

#### Platform-Specific
- Android: check manifest, permissions, lifecycle callbacks
- iOS: check Info.plist, entitlements, privacy manifest
- Check platform channel serialization

#### State Management (Riverpod Legacy)
- Check provider scope, ref lifecycle, autoDispose behavior
- Look for: stale providers, missing invalidation, disposed refs

### Phase 5: Root-Cause Drill-Down

Apply **5 Whys** with confidence scores:

```
Symptom: [what the user reports]
Why 1:  [immediate cause]              — Confidence: X.X
Why 2:  [cause of the cause]           — Confidence: X.X
Why 3:  [deeper cause]                 — Confidence: X.X
Why 4:  [systemic or architectural]    — Confidence: X.X
Why 5:  [root cause]                   — Confidence: X.X
```

### Phase 6: Cross-Reference

- Search the project's GitHub issues for duplicates
- Check if related PRs exist
- Look at recent commits near the affected code (`git log --oneline -20 -- <path>`)
- Check CHANGELOG for breaking changes near the version boundary

### Phase 7: Resolution Strategy

1. **Categorize the resolution owner** — is this a code fix, config change,
   upstream issue, or user error?

2. **Propose 1-3 fix hypotheses**, each with:
   - Root cause addressed
   - Confidence score (0.0-1.0)
   - Specific file(s) and function(s) to modify
   - Proposed code change (diff or pseudocode)
   - Regression risk: what else could break?
   - Test plan: what coverage is needed?

3. **Immediate workaround** — always provide one.

## Output Template

```markdown
## Investigation: [Issue Title] (#[number])

**Type**: Bug | Regression | Crash | Performance
**Layer(s)**: [from Phase 1]
**Repro Grade**: [A-F]
**Overall Confidence**: [0.0-1.0]

---

### Summary
[One paragraph: what is broken, when, where, for whom]

### Environment
[Relevant version matrix — only entries that matter]

### Reproduction
- **Steps**: [numbered]
- **Expected**: [what should happen]
- **Actual**: [what does happen]
- **Frequency**: [percentage or conditions]

### Root-Cause Analysis

#### 5 Whys
[Formatted chain with confidence scores]

#### Suspect Code Path
[repo -> file -> class -> method -> line]

#### Key Insight
[One sentence: the deepest "aha" of the investigation]

### Related Issues & PRs
| # | Title | Status | Relationship |
|---|-------|--------|-------------|

### Fix Strategy

#### Recommended Approach
- **Confidence**: [0.0-1.0]
- **Files to modify**: [list with paths]
- **Proposed change**: [diff or pseudocode]
- **Regression risk**: [assessment]

#### Alternative Approaches
[If applicable, with confidence scores]

#### Test Plan
- **Test that would have caught this**: [answer]
- [Specific test cases to add]

### Workaround
[Immediate, copy-pasteable workaround]
[Explain WHY it works and WHEN it can be removed]

### Open Questions
[Anything unresolved, areas with confidence below 0.5]

### Next Actions
1. [First action]
2. [Second action]
3. [Third action]
```

## Tool Reference

| Need | Tool |
|------|------|
| Fetch issue | `gh issue view <N> --json title,body,comments,labels,state` |
| Issue hierarchy | `gh api graphql` (sub-issues, parent, type) |
| Find files | `Glob` |
| Search code | `Grep` |
| Read source | `Read` |
| Git history | `git log --oneline -20 -- <path>` |
| Analyze code | `mcp__dart__analyze_files` |
| Find symbols | `mcp__dart__resolve_workspace_symbol` |
| Nostr protocol | `mcp__nostr__read_nip`, `mcp__nostr__read_kind` |
| Run tests | `mcp__dart__run_tests` or `flutter test` |

## When to Use /investigate vs /plan

| Scenario | Use |
|----------|-----|
| Routine feature implementation | `/plan` |
| Simple, localized bug | `/plan` |
| Complex or cross-layer bug | `/investigate` |
| Regression with unknown cause | `/investigate` |
| Performance issue | `/investigate` |
| Crash with native stack trace | `/investigate` |
| Issue where root cause is unclear | `/investigate` |
