---
name: claudeception
description: Use when reviewing what was learned after debugging, workaround discovery, or trial-and-error investigation, and capture it as a dated journal entry under ~/.claude/journal
---

# Claudeception

Claudeception captures episodic memory from work sessions.

It does not create or update skills. Its job is to preserve what happened, what was learned, and why it mattered in a dated journal entry that can be searched later or promoted through a separate workflow.

## When To Use

Use this skill when any of these are true:

- A task required non-obvious debugging or investigation
- A workaround or recovery path was discovered through trial and error
- An error message was misleading and the real root cause was learned
- A project-specific or system-specific constraint was uncovered
- The user asks `/claudeception`
- The user says "save this as a skill", "extract a skill from this", or "what did we learn?"

Do not use this skill to create durable procedural knowledge. If the learning should become a reusable skill, leave that for a separate promotion step.

## Core Rule

Never create a skill from this skill.

Even when the user says "save this as a skill", honor the intent by writing a journal entry unless they explicitly ask for a separate skill-writing workflow.

## Capture Threshold

Write a journal entry when the session produced knowledge that is worth preserving, even if it is narrow or specific to one system.

Good journal material:

- Incident-specific discoveries
- System quirks and deployment gotchas
- Root causes behind confusing failures
- Investigated tradeoffs and workarounds
- Repeated patterns that are not generalized yet

Skip capture when:

- The task was a routine documentation lookup
- The conclusion is already covered cleanly by an existing skill or project docs
- The note would mostly restate obvious knowledge
- The note would require storing secrets or sensitive internal details

## Output Location

Write entries to:

`~/.claude/journal/YYYY-MM-DD-topic-slug.md`

Examples:

- `~/.claude/journal/2026-04-05-fastly-draft-version-publish-mismatch.md`
- `~/.claude/journal/2026-04-05-nextjs-server-side-error-debugging.md`

If multiple notes land on the same date with the same slug, add a short suffix.

## Entry Format

Use the template in `resources/journal-entry-template.md`.

Every entry should include:

- Frontmatter with `date`, `title`, `tags`, and `source_trigger`
- A short factual description of what happened
- The actual learning, not just the symptoms
- Evidence such as errors, commands, files, or observations
- A brief reuse signal describing whether this looks one-off or recurring

Keep the note concrete. Journal entries are not polished runbooks.

## Workflow

1. Review the task or session
2. Isolate the single learning worth preserving
3. Choose a dated filename with a concise slug
4. Write the journal entry using the template
5. Include exact evidence and the real takeaway
6. Stop after writing the entry

Do not create a new skill.
Do not update an existing skill.
Do not generalize beyond what the evidence supports.

## Retrospective Mode

When `/claudeception` is invoked at the end of a session:

1. Review the session for journal-worthy learnings
2. Prefer one focused entry per distinct incident or discovery
3. If there are multiple unrelated learnings, write separate entries
4. Summarize what was captured and where it was written

## Quality Gates

Before finalizing a journal entry, verify:

- The filename is dated
- The note describes something actually observed or verified
- The writeup includes evidence or concrete trigger conditions
- The note preserves local context instead of inflating it into a general skill
- No secrets, credentials, or sensitive URLs are included
- No new skill files were created

## Anti-Patterns

- Turning every discovery into a reusable skill
- Rewriting the note as a polished runbook
- Stripping away the concrete system context that made the discovery useful
- Capturing vague conclusions without evidence
- Creating duplicate journal entries for the same learning in the same session

## Self-Check Prompts

Ask:

- What happened that was not obvious at the start?
- What was the actual root cause or constraint?
- What would future-me want to grep for?
- Is this a concrete incident note or a reusable procedure?

If it is an incident note, write it to the journal.

If it is a reusable procedure, do not create it here. Leave it for a separate promotion workflow.
