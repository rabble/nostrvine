# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

Claudeception is a Claude Code skill for continuous learning through journal capture. It preserves learned knowledge as dated markdown entries in `~/.claude/journal/`. It is not an application codebase and it does not generate reusable skills.

## Key Files

- `SKILL.md` — The main skill definition Claude Code loads
- `resources/journal-entry-template.md` — Template for captured journal entries
- `examples/` — Sample journal entries demonstrating the expected format

## Journal Entry Format

Journal entries are dated markdown files with lightweight YAML frontmatter:

```yaml
---
date: 2026-04-05
title: Fastly draft version publish mismatch
tags: [fastly, compute, deployment]
source_trigger: explicit_request
---
```

Each note should preserve:

- What happened
- What was learned
- Evidence
- Reuse signal

## Installation Paths

- **User-level**: `~/.claude/skills/claudeception/`
- **Project-level**: `.claude/skills/claudeception/`

## Quality Criteria

When modifying this skill, ensure:

- It captures episodic learnings, not generalized procedures
- It writes dated journal entries, not skill files
- It preserves concrete evidence and local context
- It does not store secrets or sensitive internal details
