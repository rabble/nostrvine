---
name: divine-context
description: Use when starting work in any divine-* repo (divine-web, divine-mobile, divine-funnelcake, keycast, divine-blossom, divine-router, etc.) or when you've learned a cross-repo fact worth sharing back. The shared divine-context handbook at ~/code/divine/divine-context/ is the source of truth for cross-cutting architecture, Nostr usage, terminology, and the project catalog across the ~50 divine-* repos.
---

# Divine Context

The [divine-context](https://github.com/divinevideo/divine-context) repo is the cross-repo handbook for the diVine platform. Every divine-* repo's `CLAUDE.md` should pull in `@../divine-context/AGENT_CONTEXT.md`, but if it doesn't, load it manually before doing real cross-repo work.

## On disk

Cloned as a sibling of the current repo:

```
~/code/divine/
├── divine-context/          ← read this
├── divine-web/
├── divine-mobile/
├── divine-funnelcake/
└── ... (~50 divine-* repos)
```

If divine-context isn't cloned:

```bash
(cd ~/code/divine && [ -d divine-context ] || gh repo clone divinevideo/divine-context)
```

## Reading divine-context

For everyday work, `AGENT_CONTEXT.md` is enough. It links out to deeper files:

| File | Read when |
|------|-----------|
| `AGENT_CONTEXT.md` | Always — single-page primer |
| `PROJECT.md` | Need product context (what diVine is, who it's for) |
| `ARCHITECTURE.md` | Touching cross-service flows |
| `PROJECTS.md` | Asking "is there already a service for X?" |
| `NOSTR.md` | Publishing/querying/signing Nostr events |
| `GLOSSARY.md` | Hit an unfamiliar term |
| `ANDOTHERSTUFF.md` | Need parent-org context |

These files describe state at the time they were written. If a file in a divine-* repo contradicts divine-context, trust the code — and if the contradiction is durable, propose a divine-context update (see below).

## Updating divine-context

When you learn a **cross-repo** fact while working in a divine-* repo, propose it back. Cross-repo means: would an agent in a *different* divine-* repo benefit from knowing this? If no, it stays in this repo's `CLAUDE.md` or `.claude/rules/`.

### Workflow

1. Read this repo's key files (5 min, no deep dive): `README.md`, `CLAUDE.md`, `AGENTS.md`, `.claude/rules/*`, `docs/**`, `package.json` / `Cargo.toml` / `pubspec.yaml` / `go.mod`, top-level `src/`.
2. Read every divine-context file (they're short).
3. Build a proposal list — for each item: one line of *what*, one line of *evidence* (`path:line` in this repo).
4. **Show the proposal list to the user before editing anything. Wait for approval.**
5. For approved items only, branch from `origin/main` (not local main, which may be stale) and make the edits:
   ```bash
   cd ~/code/divine/divine-context
   git fetch origin main
   git worktree add /tmp/dc-<topic> -b update-from-<thisrepo>-<topic>-$(date +%Y-%m-%d) origin/main
   # edit files
   cd /tmp/dc-<topic>
   git add <only the files you changed>          # never -A
   git commit -m "<short desc>: <what changed>"
   git push -u origin HEAD
   gh pr create --title "..." --body "..."
   ```
   **Use a `/tmp` worktree.** Other agents may be editing divine-context concurrently; isolating in a worktree avoids branch-state collisions.
6. **One logical change per PR.** Five unrelated improvements = five PRs.

### What goes in divine-context (and what doesn't)

| Goes in divine-context | Stays in this repo |
|------------------------|--------------------|
| Cross-repo architecture / data flow | Repo-local file paths, hooks, components |
| New event kinds, NIPs, relay gotchas | Implementation details of one repo's code |
| Domain terms an outside agent would hit cold | Repo-specific code conventions |
| `<!-- TODO -->` markers you can now answer | Debugging recipes (those go in skills/) |
| Catalog corrections in `PROJECTS.md` | One-off solutions to one repo's bug |

### Hard rules

- **Don't invent.** Cite a file path (and line if practical) in this repo for every claim. If you can't verify in 2 minutes, mark the proposed change `<!-- TODO: verify -->` instead of guessing.
- **No secrets, internal URLs, or anything sensitive.** divine-context is intended to eventually be sharable with outside contributors.
- **No copying of repo-local rules.** Flutter/BLoC specifics belong in divine-mobile, not divine-context. The "Flutter / divine-mobile specifics" subsection of `AGENT_CONTEXT.md` is the only exception.
- **Length is a budget, not a void to fill.** Prefer tightening existing prose to adding new prose. `AGENT_CONTEXT.md` is loaded into every divine-* agent's session — additions there must earn their place.
- **Don't `git add -A`.** Stage only the divine-context files you changed.
- **Don't amend existing commits.** Create new ones.
- **Don't open empty PRs.** If you have nothing to propose after reading, say so and stop.

## End-of-task report

After running the update workflow, report:

```
Proposed changes to divine-context:
- <file>: <one-line description>  — evidence: <path:line in this repo>
- ...

PR opened: <url>
(or: No PR — divine-context is accurate for this repo.)
```

## Common rationalizations to ignore

| Excuse | Reality |
|--------|---------|
| "I'll just edit divine-context directly without showing the user first" | Some proposals may be intentional omissions. Show the list first. |
| "This is repo-local but feels useful, so I'll add it anyway" | Cross-repo only. Repo-local belongs in `CLAUDE.md`. |
| "Local main looks fine, no need to fetch" | Local main may be days stale. Always branch from `origin/main`. |
| "I'll skip the worktree, just `git checkout` in place" | Concurrent agents may be editing. Use `/tmp/dc-<topic>` worktree. |
| "I'll bundle five small fixes into one PR — easier to review" | One logical change per PR. Reviewers can disagree with one without blocking the others. |
| "I'll `git add -A` — faster" | Catches unrelated files. Stage by name. |
| "I can't verify this fact, but it sounds right" | Mark `<!-- TODO: verify -->` instead of inventing. |
