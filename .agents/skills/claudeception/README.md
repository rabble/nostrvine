# Claudeception

Claudeception captures what was learned during a work session as dated journal entries.

It is an episodic memory tool, not a skill generator. When Claude discovers something non-obvious through debugging, investigation, or trial and error, Claudeception writes that learning to `~/.claude/journal/` so it can be searched later or promoted through a separate workflow.

## Installation

### Step 1: Clone the skill

**User-level (recommended)**

```bash
git clone https://github.com/blader/Claudeception.git ~/.claude/skills/claudeception
```

**Project-level**

```bash
git clone https://github.com/blader/Claudeception.git .claude/skills/claudeception
```

### Step 2: Set up the activation hook (recommended)

The skill can activate via semantic matching, but a hook ensures it evaluates every session for journal-worthy learnings.

1. Create the hooks directory and copy the script:

```bash
mkdir -p ~/.claude/hooks
cp ~/.claude/skills/claudeception/scripts/claudeception-activator.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/claudeception-activator.sh
```

2. Add the hook to your Claude settings (`~/.claude/settings.json`):

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/claudeception-activator.sh"
          }
        ]
      }
    ]
  }
}
```

If you already have a `settings.json`, merge the `hooks` configuration into it.

The hook injects a reminder on every prompt that tells Claude to evaluate whether the task produced a journal-worthy learning.

## Usage

### Automatic Mode

The skill activates automatically when Claude:

- Just completed debugging and found a non-obvious root cause
- Discovered a workaround through investigation or trial and error
- Resolved an error where the visible symptom hid the real issue
- Learned a project-specific or system-specific constraint
- Completed a task where the solution required meaningful discovery

### Explicit Mode

Trigger a learning retrospective:

```text
/claudeception
```

Existing phrases still work:

```text
Save what we just learned as a skill
```

```text
What did we learn?
```

These now create a journal entry instead of a skill.

## What Gets Captured

Claudeception captures incident notes, discoveries, and debugging outcomes that are worth preserving even when they are narrow or system-specific.

It does not create skills. Promotion to reusable skills is a separate, higher-bar workflow.

## How It Works

Claude skills should stay small and procedural. Journal entries should absorb the episodic sprawl.

Claudeception keeps that boundary clean by writing dated markdown notes under `~/.claude/journal/`:

```text
~/.claude/journal/2026-04-05-fastly-draft-version-publish-mismatch.md
~/.claude/journal/2026-04-05-nextjs-server-side-error-debugging.md
```

Each entry is a factual note about what happened, what was learned, and what evidence supports it. The retrieval mechanism for these notes is search, not startup skill loading.

## Journal Entry Format

Entries use lightweight frontmatter and a small set of sections:

```md
---
date: 2026-04-05
title: Fastly draft version publish mismatch
tags: [fastly, compute, deployment]
source_trigger: explicit_request
---

# What happened

...

# What was learned

...

# Evidence

...

# Reuse signal

...
```

See `resources/journal-entry-template.md` for the full template.

## Quality Gates

Claudeception is selective, but the threshold is lower than skill creation. A note only needs to preserve something that was genuinely learned and would be annoying to rediscover.

It should not:

- Create reusable procedural skills
- Rewrite incident notes into generalized runbooks
- Store secrets or sensitive internal details
- Turn obvious documentation lookups into memory

## Examples

See `examples/` for sample journal entries:

- `2026-01-15-nextjs-server-side-error-debugging.md`
- `2026-01-16-prisma-connection-pool-exhaustion.md`
- `2026-01-17-typescript-circular-dependency.md`

## Contributing

Contributions welcome. Fork, make changes, submit a PR.

## License

MIT
