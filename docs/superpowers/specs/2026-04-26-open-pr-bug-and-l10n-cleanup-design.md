# Open-PR Bug and L10n Cleanup — Design

Date: 2026-04-26
Status: Approved (brainstorming complete)

## Goal

Move eight open PRs forward by addressing concrete, code-level defects and
localization gaps without expanding scope into the open design / product /
infra-blocked questions on those same PRs.

This spec is the parent design for eight independent fixes. Each fix gets its
own implementation plan and worktree.

## Scope (in)

Five behavior bugs:

1. **#3301** — Zendesk attachment `uploadToken` is logged on Android and iOS.
2. **#3433** — Same-comment upvote and downvote events run as separate droppable
   handlers, allowing opposite votes to interleave.
3. **#3430** — Like and repost publishes are fire-and-forget; rapid toggles can
   settle out of order and restore stale state.
4. **#3407** — `_isTrimmingLayer` in the video editor canvas is sourced from a
   `previous` transition value, leaving it stuck `true` after trim end.
5. **#3440** — iOS QA slot allocator can let a newer PR jump an older queued
   PR; non-target PRs skip changed-file context.

Three localization sweeps (existing PRs flagged with hardcoded user-facing
strings):

6. **#3375** — Awarded-invites notification / settings flow.
7. **#3177** — Retry user-facing strings in publish primitives and repost
   feedback.
8. **#2878** — C2PA-verified video import UI.

## Scope (out)

- Resolving non-trivial merge conflicts (handed back to PR authors).
- Design or product decisions (e.g. #3314 hashtag follow behavior, #2812 live
  spaces foundations, #3244 list-add UI parity).
- Drafts blocked on external work (Zendesk secure-download provisioning,
  manual device QA, etc.).
- Refactors beyond what each fix strictly requires.

## Constraints

- **No edits on `main`.** Each PR is fixed in its own git worktree off the
  PR's branch.
- **Intent first.** For every PR, the PR description, linked issue, and any
  referenced spec are read before any code is changed. The fix must serve the
  feature's intent, not redefine it.
- **L10n is mandatory.** Any user-facing string introduced or modified passes
  through `lib/l10n/app_en.arb`. Hardcoded strings encountered in adjacent
  code on a fix are routed through l10n as part of the fix rather than
  perpetuated. After ARB changes, l10n codegen runs and generated files are
  committed.
- **Regression tests.** Each bug fix ships with a test that would have caught
  the bug. L10n sweeps update existing widget tests that reference moved
  strings.
- **No destructive git operations** without explicit user approval.

## Per-PR intent + fix sketch

### #3301 — stop logging Zendesk `uploadToken`
- **Intent.** Local logging while debugging the upload flow. The token is a
  short-lived Zendesk secure-download credential; nothing about the feature
  requires it in logs.
- **Fix.** Remove `uploadToken` from log statements in
  `mobile/android/app/src/main/kotlin/.../MainActivity.kt:591` and
  `mobile/ios/Runner/AppDelegate.swift:433`. Add a one-line comment noting
  the value must not be logged. Grep for any other call sites.
- **Verification.** `git grep` shows no `uploadToken` in log lines.
- **L10n.** None (no UI strings).

### #3433 — serialize cross-type comment vote events
- **Intent.** Allow a user to toggle and switch between upvote and downvote
  on a single comment without state desync.
- **Fix.** Replace the two `droppable()` handlers at
  `comments_bloc.dart:77` and `:78` with a single `CommentVoteRequested`
  event carrying a `vote` enum, processed with `sequential()` transformer
  keyed by `commentId` (or a single combined handler that serializes per
  comment). The previous `voteInProgressCommentId` removal stays.
- **Verification.** Bloc test: rapid up → down → up emits the final up state
  with consistent counts.
- **L10n.** None.

### #3430 — version-token guard for like/repost optimistic settle
- **Intent.** Make likes and reposts feel instant with optimistic counts,
  reconciled when the relay confirms.
- **Fix.** Track a per-(videoId, action) version token in
  `VideoInteractionsState`. Each tap increments and captures the token.
  Settle events carry their originating token; only apply the settle if the
  token still matches the latest. Stale settles are dropped.
- **Verification.** Bloc test: simulate two `Toggle` events whose publishes
  resolve in reverse order; final state matches the latest tap.
- **L10n.** None.

### #3407 — drive `_isTrimmingLayer` from current state
- **Intent.** Suppress player position updates while the user is dragging
  trim handles so the preview doesn't fight the gesture.
- **Fix.** In `video_editor_canvas.dart:779`, source `_isTrimmingLayer` from
  the *current* `state.trimmingItemId` rather than the previous transition.
  Ensure the trim-end transition deterministically resets it. Resolve new
  merge conflicts before fix work.
- **Verification.** Widget test if feasible; otherwise flag for device QA.
- **L10n.** None.

### #3440 — queue fairness in iOS QA slot allocator
- **Intent.** Allocate iOS QA build slots fairly so PRs are tested in the
  order they queued.
- **Fix.** In `.github/workflows/mobile_ios_qa_allocate.yml:174-185`, run
  the changed-file context check for all PRs in the queue, not only the
  current target. In `scripts/ios_qa_slots.py:662-664`, preserve the queued
  PR list across runs (not just occupied slots) so an older queued PR
  cannot be jumped by a newer one.
- **Verification.** Unit test for the allocator with mixed queued and
  occupied state.
- **L10n.** None.

### #3375 — l10n sweep for `invites_screen.dart`
- **Intent.** Surface awarded invites in notifications, settings, and the
  invites screen.
- **Fix.** Move hardcoded strings at lines 37, 85, 100, 187, 235, 256 (and
  any others discovered) into `app_en.arb` with descriptive keys. Update any
  widget tests that reference the literal strings. Run l10n codegen.
- **Verification.** `flutter analyze` passes; widget tests pass; visual
  parity confirmed via golden updates only if a golden references one of
  the moved strings.
- **L10n.** This is the work.

### #3177 — l10n sweep for retry strings
- **Intent.** Reliable Nostr publish primitives + NIP-09 deletion migration;
  retry UX must be localized.
- **Fix.** Identify retry-related hardcoded strings flagged in review.
  Move into `app_en.arb` with keys. Wire callers through `AppLocalizations`.
  Codegen + commit. Address adjacent review comments only when they are
  trivial and string-related (not API or feature-shape changes).
- **Verification.** `flutter analyze` + targeted tests pass.
- **L10n.** This is the work.

### #2878 — l10n sweep for C2PA import UI
- **Intent.** C2PA-verified video import via the share sheet.
- **Fix.** Move hardcoded import-flow user-facing strings into
  `app_en.arb` with keys. Codegen + commit. Do not touch
  `video_import_service.dart:102` `proofManifestJson` issue (separate
  defect, out of l10n scope).
- **Verification.** `flutter analyze` + targeted tests pass.
- **L10n.** This is the work.

## Order of work

Security → correctness → UX → infra → l10n. Each is independent of the
others; this is just the recommended sequence:

1. #3301 (security; isolated; fast)
2. #3433 (correctness; small surface)
3. #3430 (correctness; more state plumbing)
4. #3407 (UX; may need device verification)
5. #3440 (infra; CI / Python)
6. #3375 (l10n; smallest sweep)
7. #3177 (l10n; cross-cutting)
8. #2878 (l10n; import UI)

## Per-PR loop

For each PR:

1. Read PR description, linked issue, original design doc.
2. Read affected code paths end-to-end on the PR branch (not just the diff).
3. Reproduce the defect (failing test or stepwise trace).
4. Fix in a worktree off the PR branch.
5. Add regression test (bug) or update widget tests (l10n sweep).
6. Run `cd mobile && mise exec -- flutter analyze lib test`.
7. Run targeted tests.
8. If ARB touched: run l10n codegen and commit generated files.
9. Push commits directly to the PR branch. Fallback: open a follow-up PR
   targeting the original PR's branch if push to a fork is unavailable.
10. Comment on the PR linking the fix commit and summarizing what changed
    and why.

## Risks

- **#3407 reproducibility.** The trim flag bug may not be observable in
  widget tests; if the fix can't be verified without a device, surface that
  to the user before pushing.
- **L10n string drift.** Sweeping strings may collide with concurrent
  changes in the same files on `main` once those PRs rebase. Each sweep
  stays inside the PR's branch; rebases stay with the PR author.
- **PR branch push permissions.** If a PR is from a fork without
  collaborator-edit access, the fallback path is a new PR targeting that
  branch. The user is informed if this happens.

## Verification (overall)

Per-PR verification is described above. A final pass after all eight fixes:

- All eight PR branches build (`flutter analyze`).
- All eight PR branches' targeted tests pass.
- No remaining `uploadToken` log statements in the repo (#3301 cross-check).
- L10n ARB files validated by codegen on each affected PR branch.

## Out of scope (explicit)

- The other eight open PRs (#3445, #3445 review, #3314, #3244, #3242,
  #2812, #2508, #2417, #1907) — each has open design or external blockers
  that this spec does not attempt to resolve.
- Refactors of state shape, l10n architecture, or BLoC patterns beyond
  what each fix needs.
- Adding new tests to existing passing code paths (focus stays on
  regression coverage for the bugs being fixed).
