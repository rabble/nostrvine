---
name: review-before-commit
description: |
  Review all uncommitted changes before pushing. Checks for dead code,
  stale comments, CLAUDE.md rule violations, unused imports, and
  inconsistencies introduced during the current session.
  Invoke with /review-before-commit.
author: Claude Code
version: 1.0.0
date: 2026-02-10
user_invocable: true
invocation_hint: /review-before-commit
arguments: |
  Optional: Scope the review to specific paths
  Example: /review-before-commit
  Example: /review-before-commit lib/blocs/hashtag_feed/
---

# Review Skill

## Purpose
Final code review of all uncommitted changes before pushing. Catches issues
that are easy to introduce during iterative development: stale comments
referencing removed code, dead code, rule violations, and inconsistencies.

## How to Review

### Step 1: Identify changed files

Run `git diff --name-only` and `git diff --cached --name-only` to get the full
list of modified files (staged + unstaged). If the user provided a path argument,
filter to only files under that path.

### Step 2: Read all changed files

Read every changed file in full. For each file, check the items below.

### Step 3: Run checks

For each changed file, check for:

#### Dead Code
- Unused imports (import not referenced anywhere in the file)
- Unused private fields, methods, or getters
- Unreachable code after early returns
- Commented-out code blocks (should be deleted, not commented)

#### Stale References
- Comments or doc strings referencing methods, classes, or variables that no
  longer exist in the codebase (use Grep to verify references are still valid)
- ABOUTME comments that no longer accurately describe the file
- TODO comments for work that was already completed in this session

#### CLAUDE.md Rule Violations
Read and apply ALL rules from `.claude/CLAUDE.md` and `.claude/rules/`. Do not
hardcode specific rules here — always check the source of truth in those files.

#### Flutter Patterns — Known Review Findings

These patterns emerged from past review cycles on this repo and are not in the
always-loaded rules (to keep the global context window lean). Check for them
explicitly during code review.

**Design System**

- **Bespoke widget diverges from `divine_ui` without a docstring note.** Any
  widget that deliberately differs from a `divine_ui` component (different size,
  different structure, bypassed variant) must say *why* in its class docstring —
  which design-system component it's close to and what forced the divergence.
  Without it, reviewers will re-raise "why not just use `DivineIconButton`?"

  ```dart
  // Good
  /// Visually equivalent to a [DivineIconButton] in ghost style but sized 64×64
  /// with a 32 px icon instead of DivineIconButton's 40×40/56×56 presets,
  /// because the Figma spec (node 15314:53971) calls for a larger tap target
  /// than any standard DivineIconButton size.
  class CenterPlaybackControl extends StatelessWidget { ... }
  ```

**Widget API Design**

- **Speculative parameters on reusable widgets.** Before adding a parameter to
  anything in `divine_ui` or `lib/utils/`, confirm the branch it unlocks is
  reachable from at least one caller. A `Builder`/`Callback`/`Resolver`
  parameter with exactly one caller that always supplies it is a dead branch.
  Delete it — adding it back later is cheap; dead branches confuse readers and
  inflate the API surface.

  ```dart
  // Bad — initialChildSizeBuilder is only called from a surface where
  // the keyboard is never open, so the branch is unreachable.
  static Future<T?> show<T>({
    double initialChildSize = 0.6,
    double Function(BuildContext)? initialChildSizeBuilder,
  }) { ... }

  // Good — speculative branch deleted.
  static Future<T?> show<T>({double initialChildSize = 0.6}) { ... }
  ```

- **Ancestor injection via a one-off builder closure.** When a call site needs
  to put a `BlocProvider` / `InheritedWidget` above every slot of a
  modal/sheet/route, add a `contentWrapper` parameter to the target instead of
  passing a `Widget Function(BuildContext, Widget)` closure at the call site.
  The closure is a `_buildFoo` in disguise and silently misses new slots added
  later.

  ```dart
  // Bad — builder closure baked into the call site.
  showMySheet(context, builder: (ctx, child) => BlocProvider<MyBloc>(
    create: (_) => MyBloc(), child: child));

  // Good — target exposes contentWrapper; provider covers every slot.
  showMySheet(context,
    contentWrapper: (ctx, child) => BlocProvider<MyBloc>(
      create: (_) => MyBloc(), child: child));
  ```

**State Management**

- **Modal-scoped bloc instantiated at the call site with `try/finally close()`.
  ** Put the `BlocProvider` *inside* the modal's subtree (via `contentWrapper`
  or equivalent). `BlocProvider` handles the close automatically on unmount —
  any route that pops via a path other than `await` returning silently leaks the
  bloc in the `try/finally` pattern.

  ```dart
  // Bad — lifecycle managed at call site.
  final bloc = CommentsBloc()..add(const CommentsLoadRequested());
  try {
    await showSheet(title: BlocProvider.value(value: bloc, child: _Title()));
  } finally {
    await bloc.close();
  }

  // Good — BlocProvider owns the close on unmount.
  return showSheet(
    contentWrapper: (ctx, child) => BlocProvider<CommentsBloc>(
      create: (_) => CommentsBloc()..add(const CommentsLoadRequested()),
      child: child),
    title: _Title());
  ```

**Comments**

- **Multi-line design-rationale comments for Claude's benefit.** Paragraph-
  length inline comments drift the moment the code changes, and LLMs cite them
  as authoritative even when stale. If the explanation is more than one sentence,
  move it to the PR description or a rule file and leave a `// See PR #N` pointer
  inline — not the full paragraph.

  ```dart
  // Bad — paragraph above ClipRRect that will silently drift.
  // The outer shell uses 30 px bottom corners and the inner tabs container
  // uses 32 px top corners so that the inner surface visibly nests ...
  ClipRRect(borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)));

  // Good — rationale lives in the named constant.
  // Inner radius is 2 px larger so the tabs container visibly nests.
  ClipRRect(borderRadius: BorderRadius.vertical(
    bottom: Radius.circular(VineTheme.shellCornerRadius)));
  ```

**UI / Animations**

- **Redundant `ValueKey` on `AnimatedSwitcher` branches that are already
  different runtime types.** `AnimatedSwitcher` compares `runtimeType + key`.
  Branches that already return different widget types (`Center`, `IgnorePointer`,
  `SizedBox`, …) are already distinguishable — adding `ValueKey` is redundant
  and risks "duplicate GlobalKey" assertions when the widget is reused.
  Only add a `ValueKey` when (a) two branches are the *same* runtime type, or
  (b) a test anchors on the key via `find.byKey(...)` (leave a comment saying
  so).

- **`Timer` (or `Future.delayed`) for UI timing.** `Timer` keeps firing after
  the widget is disposed unless manually cancelled; it doesn't pause with the
  route; it doesn't respect `MediaQuery.disableAnimations`; and it can land a
  `setState` mid-frame. Use `AnimationController` + `FadeTransition` /
  `AnimatedBuilder` for transient flashes, badge pulses, or snackbar-like
  overlays. Reach for `Timer` only when the effect is genuinely outside the
  rendering pipeline (e.g. network debounce, analytics delay).

  ```dart
  // Good
  late final AnimationController _feedbackController = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 550));
  void _triggerFeedback() => _feedbackController.forward(from: 0);
  // In build:
  FadeTransition(
    opacity: Tween(begin: 1.0, end: 0.0).animate(_feedbackController),
    child: const FeedbackIcon());
  ```

**Tests**

- **Absolute wall-clock timing bounds (`<100 ns`, `<100 ms`).** Shared CI
  runners are noisy and substantially slower than dev laptops — these flake.
  Use a relative comparison (`expect(fastMs, lessThan(slowMs))`), wrap in
  `fakeAsync` for logical-duration checks, or skip with `skip: true` + a
  `TODO(any):` comment. Never bump the threshold — that just delays the next
  flake.

- **`expect(tester.takeException(), isNotNull)` as a side-effect signal.**
  `very_good test --optimization` merges test files; leaked Riverpod
  `keepAlive` state from an earlier test can silently resolve the dependency,
  suppressing the exception. Assert only the test's named contract; drain
  incidental errors without an assertion:
  ```dart
  tester.takeException(); // drain incidental error — no assertion
  ```

- **`tester.tapAt(Offset(...))` for modal interaction.** Coordinate-based taps
  are sensitive to the modal's `expand` flag: `DraggableScrollableSheet(expand:
  false)` has transparent empty space above its content, while `expand: true`
  fills that rectangle with the sheet's hit-testing. Prefer
  `find.text(...)` / `find.byType(...)` / `find.bySemanticsIdentifier(...)`.
  When `tapAt` is unavoidable, document the layout assumption inline and keep
  the offset well inside the intended region.

- **`DateTime.now()` in code compared against `tester.pump(Duration)`.** The
  Flutter test clock advances via `pump`; `DateTime.now()` reads the host wall
  clock — they don't agree. Use `package:clock`'s `clock.now()` in production
  code and `withClock(Clock(() => now), () async { ... })` in the test so both
  clocks advance together. (`clock` is already a transitive dependency — no
  `pubspec.yaml` change needed.)

  ```dart
  // Code under test:
  import 'package:clock/clock.dart';
  if (clock.now().difference(_pausedAt!) >= _minPauseForFeedback) {
    _triggerUnpauseFeedback();
  }

  // Test:
  var now = DateTime(2026);
  await withClock(Clock(() => now), () async {
    now = now.add(const Duration(milliseconds: 220));
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.byType(UnpauseFeedback), findsOneWidget);
  });
  ```

#### Test Consistency
- If production code changed, verify corresponding tests exist and still match
- Check for test assertions that reference removed fields or methods
- Verify mock setups match current method signatures

### Step 4: Run analyzer and tests

1. Run `mcp__dart__analyze_files` on all changed files
2. Run `mcp__dart__run_tests` on all changed test files
3. Report any failures

### Step 5: Report findings

Present findings grouped by severity:

```
## Review Summary

### Must Fix
- [file.dart:42](path/to/file.dart#L42) - Description of the issue

### Should Fix
- [file.dart:15](path/to/file.dart#L15) - Description of the issue

### Nitpick
- [file.dart:7](path/to/file.dart#L7) - Description of the issue

### All Clear
If no issues found, confirm: "No issues found. Ready to push."
```

**Severity definitions:**
- **Must Fix**: Will cause bugs, test failures, or CI failures
- **Should Fix**: Violates project rules, dead code, stale comments
- **Nitpick**: Style preferences, minor improvements

After reporting, fix all "Must Fix" and "Should Fix" items automatically.
Ask the user before fixing "Nitpick" items.
