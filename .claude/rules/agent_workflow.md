# Agent Workflow

The non-negotiables for branch hygiene, PR strategy, technical debt, and
test discipline. These rules apply to every change, every time. They
exist because the alternatives have already cost us — each one has a
specific failure history.

`AGENTS.md` is the entry-point summary; this file is the detailed
reference. When the two disagree, the stricter version wins.

---

## 1. Always start in a fresh worktree based on `origin/main`

**Every change starts in a NEW worktree branched from `origin/main`.**

```bash
git fetch origin
git worktree add .worktrees/<task-name> -b <branch-name> origin/main
cd .worktrees/<task-name>
```

Branch from `origin/main`, never from local `main`. Local `main` is often
stale — branching from it carries forward commits that have already been
superseded on the remote.

**Forbidden:**

- Editing on `main` (local or otherwise).
- Reusing an existing worktree for an unrelated task without first
  rebasing onto fresh `origin/main`.
- Branching from `main` without `git fetch origin` first.

One task per worktree. If the current worktree is dirty, commit, stash
intentionally, or discard intentionally before starting new work
elsewhere. Do not mix unrelated work into one worktree.

---

## 2. Always rebase onto `origin/main` before pushing

Before **every** `git push`, fetch the latest `origin/main` and rebase
your branch onto it:

```bash
git fetch origin
git rebase origin/main
# resolve any conflicts, re-run tests, then:
git push --force-with-lease
```

Rebasing right before push surfaces conflicts and broken assumptions
while you still have full context — instead of after CI fails on the PR
or after a reviewer has already started reading.

**Forbidden:**

- `git push` without first `git fetch origin && git rebase origin/main`.
- `git push --force` without `--lease`. `--force-with-lease` is
  mandatory on rebased feature branches so a concurrent push from a
  different machine isn't silently overwritten.
- Merging `main` into a feature branch instead of rebasing — produces
  noisy "Merge branch 'main' into..." commits and a non-linear history.

This rule still applies even on a branch you've pushed many times.
Don't push a stale branch.

---

## 3. Never stack PRs — combine dependent features into one bigger PR

**Every PR targets `main`.** Never `gh pr create --base <other-branch>`.

If features depend on each other, ship them as **one combined PR** on a
single branch. Use clearly delineated commits and a PR description with
separate sections for each feature. Reviewers handle one PR; the merge
story is one click; CI runs against the right base.

```bash
# One branch, both features, one PR
git checkout -b feature-a-and-b origin/main
# ... commit Feature A ...
# ... commit Feature B ...
git push --force-with-lease
gh pr create --base main
```

**Why stacking is forbidden:** every prior attempt has cost more than it
saved — cascading rebases when the parent changes, fragmented review
context, merge order becoming load-bearing, CI running against the
wrong base, and "fix on parent" forcing a re-review of the child. The
diff-cleanliness benefit isn't worth the operational cost.

**Forbidden:**

- `gh pr create --base <other-pr-branch>`. Always `--base main` (or
  omit, since `main` is the default).
- Branching a feature off another feature branch with the intent to PR
  it before the parent merges.
- Splitting truly interdependent work into multiple PRs.

If you catch yourself thinking *"B is based on A,"* that's the signal
to combine, not to stack.

If A and B are **truly independent**, each gets its own PR targeting
`main`, in any merge order — that's not stacking, that's parallel.

---

## 4. Do not accumulate technical debt

Fix it now, in the PR that introduces or touches it. No deferral, no
"we'll clean this up later," no follow-up issue as cover for shipping
half-finished work.

**Forbidden in any PR:**

- `// TODO`, `// FIXME`, `// XXX` comments deferring real work — the
  only TODO that is acceptable is the **transitional-code TODO** with a
  tracking issue link, as `code_style.md` documents (`// TODO(#1234):
  Remove after migration X ships`).
- Commented-out code blocks ("might need this later").
- `skip:` / `@Skip` / `xtest` on tests without a tracked issue and a
  hard removal date.
- `// ignore: <lint>` or `// ignore_for_file:` without an inline
  explanation of *why* the rule cannot be satisfied.
- Failing tests "we'll fix in a follow-up."
- Generated files left out of sync with their inputs.
- Dead code, unused imports, unused variables — fix them, don't
  suppress them.
- Half-finished refactors that leave both old and new code paths live.

**If a problem is bigger than the PR, scope-cut the PR — don't ship
partial work and a TODO.** Open a focused PR for just the fix you can
finish.

If you discover unrelated rot while working, leave it alone (don't
scope-creep) — but never make it worse.

Every merged PR should leave the codebase in a state you'd be happy to
inherit cold.

---

## 5. Failing tests are never acceptable, and always your fault

**`origin/main` always passes.** Therefore any failing test on a feature
branch is caused by something in that branch's diff. Full stop.

When an agent says *"this test is flaky"* or *"this was already broken
on main"* or *"we'll fix it in a follow-up,"* it is almost always
wrong. The real explanations, in order of frequency:

1. The change broke the behavior the test asserts (most common).
2. The change broke a test setup invariant — mocks, fixtures, or
   generated files (Riverpod, Freezed, JSON, Mockito, Drift) out of
   sync with their inputs.
3. The change reveals a real race or order-dependence the test
   correctly catches.
4. A genuinely flaky test — extremely rare. If you find one, fix it;
   don't tolerate it.

*"It passed locally"* is not evidence the test is flaky. It's evidence
the local environment differs from CI. Investigate the difference.

### When a test fails on your branch

1. **Assume it's your fault.** Read the failure carefully. Trace from
   the assertion back through the production code your branch changed.
2. **Compare against `origin/main`.** Run the same test on
   `origin/main`. If it passes there, the cause is in your diff:
   `git diff origin/main -- <file>`.
3. **If you touched generated-code inputs**, run
   `dart run build_runner build --delete-conflicting-outputs` from
   `mobile/` and commit the regenerated files.
4. **If the test seems unrelated**, look harder. You probably changed a
   shared dependency, a constant, a default, or a public API consumed
   by that test.
5. **Fix the underlying cause.** Do not modify the test to make it
   pass unless the test was genuinely wrong (rare — be suspicious of
   yourself when you reach for this).

### Forbidden

- *"Flaky, will retry"* — find the race or order-dependence and fix it.
- `skip:` / `@Skip` / `xtest` to silence a failing test.
- *"Already broken on main"* without verifying on `origin/main`.
- Pushing with red local tests "to see what CI says."
- Claiming "tests pass" without having actually run them — see
  `superpowers:verification-before-completion`.

### Before every push

- Run the affected test suites locally.
- Run `flutter analyze lib test integration_test`.
- Verify the rebase onto `origin/main` did not break anything.
- If anything is red, do not push. Fix it.
