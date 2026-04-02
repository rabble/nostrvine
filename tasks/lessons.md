# Lessons Learned

Operational rules derived from past mistakes and corrections. Review at session start.
Update after every correction from the user.

---

## PR Reviews

- **Always verify against actual diff**: In March 2026, PR reviews for #2423 and #2424 contained hallucinated changes not in the actual diffs. Always run `gh pr diff <number>` before writing review content. Never describe changes that are not confirmed in the diff. Hallucinated content was specific enough to sound real (event names, line counts, file references) but was entirely fabricated.

## Git Workflow

- **Push to origin, not fork**: User has full access to divinevideo/divine-mobile. Always use `git push -u origin <branch>`. No cross-fork PRs needed.

## Issue & PR Conventions

- **Always use type prefix + label**: `feat:` + `enhancement`, `fix:` + `bug`, `task:` for tasks. Do not add priority labels unless explicitly requested.
- **Link PRs to assigned issues**: Use `Closes #NNN` in PR body. Ask which issue to link if not obvious. PRs without linked issues require manual cleanup.
- **Missing functionality is a feature, not a bug**: Even if it has privacy or security implications, missing capability is `feat:` + `enhancement`, not `fix:` + `bug`.
