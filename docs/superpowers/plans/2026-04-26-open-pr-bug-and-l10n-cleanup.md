# Open-PR Bug and L10n Cleanup — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land code-level fixes on eight already-open PRs (five bugs, three l10n sweeps) without expanding into the design / product / external-blocker work those PRs also need.

**Architecture:** Each PR fix is independent. For every PR: create a worktree off the PR's branch, read intent (PR description + linked issue + spec), read affected code end-to-end, reproduce the defect, fix, regression test, l10n codegen if ARB touched, push to the PR branch, comment on the PR. Sequential, in the order security → correctness → UX → infra → l10n.

**Tech Stack:** Flutter / Dart (BLoC, Riverpod legacy), Kotlin (Android host), Swift (iOS host), Python (CI tooling), GitHub Actions YAML, ARB for l10n.

**Spec:** `docs/superpowers/specs/2026-04-26-open-pr-bug-and-l10n-cleanup-design.md`

---

## Conventions used by every task

- All `flutter` / `dart` / `mise` commands run from `mobile/` unless stated.
- Worktree path convention: `~/code/divine/divine-mobile-worktrees/pr-<NUM>-<slug>`.
- After ARB changes, run l10n codegen and commit generated files.
- After Dart code changes that affect generated outputs (Riverpod / Freezed / Mockito / JSON / Drift), run
  `dart run build_runner build --delete-conflicting-outputs` and commit generated files.
- Before any push, run `cd mobile && mise exec -- flutter analyze lib test` and the targeted tests.
- Commit messages use the project's convention (`fix:`, `chore:`, `feat:` prefixes; reference the PR number).
- Push directly to the PR's branch. If push to a fork is rejected, fall back to opening a new PR targeting the original PR's branch and link both.
- After push, leave a PR comment summarizing what changed and why. Use `gh pr comment <NUM>`.

## File-level responsibilities (by task)

| PR | Responsibility | Files |
|---|---|---|
| #3301 | Stop logging Zendesk uploadToken | `mobile/android/app/src/main/kotlin/.../MainActivity.kt:591`, `mobile/ios/Runner/AppDelegate.swift:433` |
| #3433 | Serialize cross-type comment vote events | `mobile/lib/blocs/comments/comments_bloc.dart`, `mobile/lib/blocs/comments/comments_event.dart`, regression test under `mobile/test/blocs/comments/` |
| #3430 | Version-token guard for like/repost optimistic settle | `mobile/lib/blocs/video_interactions/video_interactions_bloc.dart`, `mobile/lib/blocs/video_interactions/video_interactions_state.dart`, regression test under `mobile/test/blocs/video_interactions/` |
| #3407 | Drive `_isTrimmingLayer` from current state | `mobile/lib/screens/video_editor/widgets/video_editor_canvas.dart`, widget test under `mobile/test/screens/video_editor/` if feasible |
| #3440 | Queue fairness in iOS QA slot allocator | `.github/workflows/mobile_ios_qa_allocate.yml`, `scripts/ios_qa_slots.py`, test under `scripts/test_ios_qa_slots.py` |
| #3375 | L10n sweep for invites screen | `mobile/lib/screens/invites/invites_screen.dart`, `mobile/lib/l10n/app_en.arb`, generated l10n |
| #3177 | L10n sweep for retry strings | files flagged by review (publish primitives + repost retry feedback), `mobile/lib/l10n/app_en.arb`, generated l10n |
| #2878 | L10n sweep for C2PA import UI | C2PA import flow widgets, `mobile/lib/l10n/app_en.arb`, generated l10n |

---

## Task 1: PR #3301 — stop logging Zendesk `uploadToken`

**Files:**
- Modify: `mobile/android/app/src/main/kotlin/.../MainActivity.kt:591`
- Modify: `mobile/ios/Runner/AppDelegate.swift:433`

- [ ] **Step 1: Set up worktree off the PR branch**

```bash
gh pr checkout 3301 --detach
git fetch origin pull/3301/head:pr-3301
git worktree add ~/code/divine/divine-mobile-worktrees/pr-3301-stop-token-logging pr-3301
cd ~/code/divine/divine-mobile-worktrees/pr-3301-stop-token-logging
```

- [ ] **Step 2: Read PR intent and original code**

```bash
gh pr view 3301 --json title,body,files
gh pr view 3301 --json comments,reviews
```

Read `MainActivity.kt:580-610` and `AppDelegate.swift:420-450` to confirm what the log statements look like and why they were added.

- [ ] **Step 3: Grep for any other `uploadToken` log sites**

```bash
git grep -nE 'uploadToken' -- 'mobile/android' 'mobile/ios'
git grep -nE '(Log\.|os_log|print\().*upload[_ ]?token' -- 'mobile/android' 'mobile/ios'
```

Note all hits.

- [ ] **Step 4: Remove or redact `uploadToken` from log statements**

In `MainActivity.kt:591`, replace the log statement so the token value is not interpolated. Add a one-line Kotlin comment immediately above:

```kotlin
// Do not log uploadToken: short-lived Zendesk secure-download credential.
```

In `AppDelegate.swift:433`, do the equivalent in Swift (`// Do not log uploadToken: short-lived Zendesk secure-download credential.`). If the token was the only purpose of the log line, delete the line.

- [ ] **Step 5: Verify nothing else logs the token**

```bash
git grep -nE 'uploadToken' -- 'mobile/android' 'mobile/ios'
```

Expected: only the comment lines you just added (or no hits if you deleted the lines). No remaining log statements include `uploadToken`.

- [ ] **Step 6: Run analyzer**

```bash
cd mobile && mise exec -- flutter analyze lib test
```

Expected: no new analyzer warnings (these are native files, but analyze still passes for the Dart side).

- [ ] **Step 7: Commit**

```bash
git add mobile/android mobile/ios
git commit -m "fix(zendesk): stop logging uploadToken (PR #3301)"
```

- [ ] **Step 8: Push and comment on PR**

```bash
git push origin HEAD:$(gh pr view 3301 --json headRefName -q .headRefName)
gh pr comment 3301 --body "Removed uploadToken from log statements in MainActivity.kt and AppDelegate.swift. Tokens are short-lived Zendesk secure-download credentials and should not appear in device logs."
```

If push fails (fork without write access), open a new PR targeting the PR branch instead and link it in the comment.

---

## Task 2: PR #3433 — serialize cross-type comment vote events

**Files:**
- Modify: `mobile/lib/blocs/comments/comments_bloc.dart` (handlers at :77 and :78)
- Modify: `mobile/lib/blocs/comments/comments_event.dart` (event shape)
- Test: `mobile/test/blocs/comments/comments_bloc_test.dart`

- [ ] **Step 1: Worktree + read intent**

```bash
gh pr checkout 3433 --detach
git worktree add ~/code/divine/divine-mobile-worktrees/pr-3433-vote-race pr-3433
cd ~/code/divine/divine-mobile-worktrees/pr-3433-vote-race
gh pr view 3433 --json title,body,files,reviews
```

Read `comments_bloc.dart` end-to-end, focusing on lines 60-120. Identify:
- The two handlers at :77 (upvote) and :78 (downvote)
- The transformer used (currently `droppable()`)
- The state fields they touch (likely `votes`, `commentVoteCounts`)

- [ ] **Step 2: Write a failing bloc test for the rapid up→down→up race**

In `mobile/test/blocs/comments/comments_bloc_test.dart`, add a test that:

```dart
blocTest<CommentsBloc, CommentsState>(
  'serializes opposite votes on the same comment',
  setUp: () {
    // Stub the repository: upvote takes 50ms, downvote takes 10ms
    when(() => repository.upvote(any(), any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    when(() => repository.downvote(any(), any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
  },
  build: () => CommentsBloc(repository: repository),
  act: (bloc) async {
    bloc.add(const CommentVoteRequested(commentId: 'c1', vote: Vote.up));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const CommentVoteRequested(commentId: 'c1', vote: Vote.down));
  },
  verify: (_) {
    verifyInOrder([
      () => repository.upvote('c1', any()),
      () => repository.downvote('c1', any()),
    ]);
  },
);
```

- [ ] **Step 3: Run the test and confirm failure**

```bash
cd mobile && mise exec -- flutter test test/blocs/comments/comments_bloc_test.dart --plain-name "serializes opposite votes"
```

Expected: FAIL because (a) `CommentVoteRequested` doesn't exist yet, or (b) ordering is not guaranteed.

- [ ] **Step 4: Replace the two events with a single `CommentVoteRequested`**

In `comments_event.dart`, add:

```dart
enum Vote { up, down, none }

class CommentVoteRequested extends CommentsEvent {
  const CommentVoteRequested({required this.commentId, required this.vote});
  final String commentId;
  final Vote vote;

  @override
  List<Object?> get props => [commentId, vote];
}
```

Keep the old `CommentUpvoteRequested` / `CommentDownvoteRequested` events deprecated only if they have external callers; otherwise remove them.

- [ ] **Step 5: Replace the two handlers with one sequential handler**

In `comments_bloc.dart`, register a single handler with `sequential()` transformer:

```dart
on<CommentVoteRequested>(_onVoteRequested, transformer: sequential());
```

Implement `_onVoteRequested` to dispatch to repository based on `event.vote`. Handler must serialize per (commentId, vote) by virtue of `sequential()` running events in FIFO order.

If finer-grained per-`commentId` concurrency is needed (different comments can vote simultaneously), use a custom transformer that groups by `commentId`:

```dart
EventTransformer<E> _serializePerComment<E extends CommentsEvent>(
  String Function(E) keyOf,
) {
  return (events, mapper) => events
      .groupBy(keyOf)
      .flatMap((group) => group.asyncExpand(mapper));
}
```

(If `groupBy`/`flatMap` aren't available, document the simpler `sequential()` choice and move on.)

Update call sites that previously dispatched `CommentUpvoteRequested` / `CommentDownvoteRequested` to dispatch `CommentVoteRequested` with the appropriate `Vote`. Remove the `voteInProgressCommentId` state field and any UI guards that referenced it.

- [ ] **Step 6: Re-run the failing test**

```bash
cd mobile && mise exec -- flutter test test/blocs/comments/comments_bloc_test.dart --plain-name "serializes opposite votes"
```

Expected: PASS.

- [ ] **Step 7: Run the full comments bloc test file**

```bash
cd mobile && mise exec -- flutter test test/blocs/comments/comments_bloc_test.dart
```

Expected: PASS.

- [ ] **Step 8: Run analyze**

```bash
cd mobile && mise exec -- flutter analyze lib test
```

Expected: no new warnings.

- [ ] **Step 9: Commit**

```bash
git add mobile/lib/blocs/comments mobile/test/blocs/comments
git commit -m "fix(comments): serialize cross-type vote events to prevent race (PR #3433)"
```

- [ ] **Step 10: Push and comment**

```bash
git push origin HEAD:$(gh pr view 3433 --json headRefName -q .headRefName)
gh pr comment 3433 --body "Replaced two droppable upvote/downvote handlers with a single CommentVoteRequested handled with sequential transformer, preventing opposite votes on the same comment from interleaving. Added a bloc test that drives up→down on one comment and verifies repository calls happen in order."
```

---

## Task 3: PR #3430 — version-token guard for like/repost optimistic settle

**Files:**
- Modify: `mobile/lib/blocs/video_interactions/video_interactions_bloc.dart` (around :204)
- Modify: `mobile/lib/blocs/video_interactions/video_interactions_state.dart`
- Test: `mobile/test/blocs/video_interactions/video_interactions_bloc_test.dart`

- [ ] **Step 1: Worktree + read intent**

```bash
gh pr checkout 3430 --detach
git worktree add ~/code/divine/divine-mobile-worktrees/pr-3430-like-repost-race pr-3430
cd ~/code/divine/divine-mobile-worktrees/pr-3430-like-repost-race
gh pr view 3430 --json title,body,files,reviews
```

Read the bloc and state classes. Identify:
- The fire-and-forget call site at `:204`
- How settle (relay confirmation) currently flows back into state
- Existing fields (`likedVideoIds`, `repostedVideoIds`, count maps)

- [ ] **Step 2: Write a failing bloc test for out-of-order settle**

```dart
blocTest<VideoInteractionsBloc, VideoInteractionsState>(
  'discards stale settle for a video whose toggle has been superseded',
  setUp: () {
    final controller1 = Completer<void>();
    final controller2 = Completer<void>();
    var call = 0;
    when(() => repo.publishLike(any())).thenAnswer((_) {
      call++;
      return call == 1 ? controller1.future : controller2.future;
    });
  },
  build: () => VideoInteractionsBloc(repository: repo),
  act: (bloc) async {
    bloc.add(const ToggleLike('vid1'));   // optimistic: liked=true
    await Future<void>.delayed(Duration.zero);
    bloc.add(const ToggleLike('vid1'));   // optimistic: liked=false
    await Future<void>.delayed(Duration.zero);
    controller2.complete();               // second publish settles first
    await Future<void>.delayed(Duration.zero);
    controller1.complete();               // first publish settles late
  },
  verify: (bloc) {
    expect(bloc.state.isLiked('vid1'), isFalse);
  },
);
```

- [ ] **Step 3: Run and confirm failure**

```bash
cd mobile && mise exec -- flutter test test/blocs/video_interactions/video_interactions_bloc_test.dart --plain-name "discards stale settle"
```

Expected: FAIL — final state shows liked=true because the late settle from publish #1 overwrote the latest user state.

- [ ] **Step 4: Add per-(videoId, action) version token to state**

In `video_interactions_state.dart`:

```dart
// Increments on each user toggle. Settle events carry the token captured
// at dispatch time; out-of-order settles whose token != current are dropped.
final Map<(String, InteractionAction), int> _toggleTokens;

int tokenFor(String videoId, InteractionAction action) =>
    _toggleTokens[(videoId, action)] ?? 0;
```

Make `copyWith` accept an updated token map.

- [ ] **Step 5: Capture token on dispatch, check on settle**

In the `ToggleLike` / `ToggleRepost` handlers around `:204`:

```dart
final token = state.tokenFor(event.videoId, action) + 1;
emit(state.copyWith(/* optimistic update */, withToken: (event.videoId, action, token)));

try {
  await _repository.publishLike(event.videoId);
  if (state.tokenFor(event.videoId, action) != token) {
    return; // user toggled again; this settle is stale.
  }
  emit(state.copyWith(/* confirmed */));
} catch (e, s) {
  if (state.tokenFor(event.videoId, action) != token) return;
  addError(e, s);
  emit(state.copyWith(/* rollback */, status: ...failure));
}
```

Replace fire-and-forget with awaited publish under a `sequential()` transformer keyed by videoId if available, but the token guard alone is sufficient for correctness; the sequential transformer is an additional safety net if you choose to add it.

- [ ] **Step 6: Re-run the failing test**

Expected: PASS.

- [ ] **Step 7: Run the full video_interactions bloc test file**

```bash
cd mobile && mise exec -- flutter test test/blocs/video_interactions
```

Expected: PASS.

- [ ] **Step 8: Run analyze + codegen if state class uses Freezed**

```bash
cd mobile && mise exec -- dart run build_runner build --delete-conflicting-outputs
cd mobile && mise exec -- flutter analyze lib test
```

- [ ] **Step 9: Commit**

```bash
git add mobile/lib/blocs/video_interactions mobile/test/blocs/video_interactions
git commit -m "fix(video-interactions): version-token guard for like/repost settle (PR #3430)"
```

- [ ] **Step 10: Push and comment**

```bash
git push origin HEAD:$(gh pr view 3430 --json headRefName -q .headRefName)
gh pr comment 3430 --body "Added per-(videoId, action) version token to VideoInteractionsState. Each ToggleLike/ToggleRepost increments the token; the publish awaits its result and only emits the confirmed/rollback state if its captured token still matches the current state. Out-of-order settles from rapid taps are dropped. Bloc test added for two-tap reversed-resolution scenario."
```

---

## Task 4: PR #3407 — drive `_isTrimmingLayer` from current state

**Files:**
- Modify: `mobile/lib/screens/video_editor/widgets/video_editor_canvas.dart:779`
- Test: `mobile/test/screens/video_editor/widgets/video_editor_canvas_test.dart` (if widget test feasible)

- [ ] **Step 1: Worktree + read intent**

```bash
gh pr checkout 3407 --detach
git worktree add ~/code/divine/divine-mobile-worktrees/pr-3407-trim-flag pr-3407
cd ~/code/divine/divine-mobile-worktrees/pr-3407-trim-flag
gh pr view 3407 --json title,body,files,reviews
```

Read `video_editor_canvas.dart` around `:740-820` to understand:
- Where `_isTrimmingLayer` is set
- What `previous.trimmingItemId` vs `current.trimmingItemId` look like at the relevant transition
- Why the suppression matters (player position updates fight the gesture)

- [ ] **Step 2: Resolve any merge conflicts on the PR branch**

```bash
git fetch origin
git rebase origin/main
```

If conflicts, resolve them, run `flutter analyze`, and continue. Stop and report if conflicts are non-trivial — the spec excludes hard conflicts from scope.

- [ ] **Step 3: Try to write a widget test**

Goal: a widget test that drives the editor through trim-start → trim-drag → trim-end and asserts `_isTrimmingLayer` is `false` at the end. If the flag isn't directly observable, assert on a downstream observable (e.g., player position update count).

If the widget test is not feasible without a real video player, skip the test step and document this as a manual-QA item.

- [ ] **Step 4: Change `_isTrimmingLayer` source**

Replace the line at `:779`:

```dart
// Was: final isTrimmingLayer = previous.trimmingItemId != null;
final isTrimmingLayer = current.trimmingItemId != null;
```

Trace the surrounding `BlocListener<...>(listenWhen: ..., listener: (context, state) { ... })` block to confirm `current` is in scope. If not, refactor the closure so the flag is recomputed from the current state on every relevant emit.

- [ ] **Step 5: Verify trim-end clears the flag deterministically**

Walk through the BLoC: when the user releases the trim handle, the bloc emits a state with `trimmingItemId == null`. Confirm the listener fires for that emit and `isTrimmingLayer` becomes `false`. Add a comment above the line:

```dart
// Source from current state, not the previous transition value: a transition
// to trimmingItemId == null must clear the flag, and reading from `previous`
// keeps the prior non-null id and leaves the flag stuck.
```

- [ ] **Step 6: Run analyze + targeted tests**

```bash
cd mobile && mise exec -- flutter analyze lib test
cd mobile && mise exec -- flutter test test/screens/video_editor
```

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/screens/video_editor mobile/test/screens/video_editor
git commit -m "fix(video-editor): clear _isTrimmingLayer from current state (PR #3407)"
```

- [ ] **Step 8: Push and comment**

```bash
git push origin HEAD:$(gh pr view 3407 --json headRefName -q .headRefName)
gh pr comment 3407 --body "Source _isTrimmingLayer from current state.trimmingItemId; reading from previous left the flag stuck true after the trim-end transition because previous still pointed at the active trim item. <Note widget test status>. Flagging device QA: please confirm the live preview no longer continues suppressing position updates after releasing a trim handle."
```

---

## Task 5: PR #3440 — queue fairness in iOS QA slot allocator

**Files:**
- Modify: `.github/workflows/mobile_ios_qa_allocate.yml:174-185`
- Modify: `scripts/ios_qa_slots.py:662-664`
- Test: `scripts/test_ios_qa_slots.py`

- [ ] **Step 1: Worktree + read intent**

```bash
gh pr checkout 3440 --detach
git worktree add ~/code/divine/divine-mobile-worktrees/pr-3440-queue-fairness pr-3440
cd ~/code/divine/divine-mobile-worktrees/pr-3440-queue-fairness
gh pr view 3440 --json title,body,files,reviews
```

Read the workflow YAML and the allocator script. Understand:
- What "occupied" vs "queued" mean in `ios_qa_slots.py`
- Why the workflow's changed-file context check only runs for the target PR
- The allocator's selection algorithm for the next PR to fill a freed slot

- [ ] **Step 2: Write a unit test for the unfairness scenario**

In `scripts/test_ios_qa_slots.py`:

```python
def test_older_queued_pr_is_not_jumped():
    state = {
        "occupied": {"slot-a": {"pr": 100, "queued_at": "2026-04-26T10:00:00Z"}},
        "queued":   [{"pr": 200, "queued_at": "2026-04-26T11:00:00Z"}],
    }
    # New PR 300 arrives at 12:00.
    new_state = allocate(state, new_pr=300, now="2026-04-26T12:00:00Z", free_slots=[])
    # Expected: 200 is still ahead of 300 in queue
    assert [p["pr"] for p in new_state["queued"]] == [200, 300]

def test_freed_slot_goes_to_oldest_queued():
    state = {
        "occupied": {},
        "queued":   [{"pr": 200}, {"pr": 300}, {"pr": 100}],  # by queued_at ascending
    }
    new_state = allocate(state, free_slots=["slot-a"])
    assert new_state["occupied"]["slot-a"]["pr"] == 200
```

(Field names are illustrative — adapt to the actual data shape in `ios_qa_slots.py`.)

- [ ] **Step 3: Run and confirm failure**

```bash
cd scripts && python -m pytest test_ios_qa_slots.py::test_older_queued_pr_is_not_jumped -v
```

Expected: FAIL because the current allocator drops the queued PR list across runs.

- [ ] **Step 4: Persist queued PRs across runs**

In `ios_qa_slots.py:662-664`, change the persistence call so the saved blob contains both `occupied` and `queued` lists. Restore both on the next run. Sort `queued` by `queued_at` ascending whenever it is mutated. When a slot frees, allocate it to the head of `queued` before considering any newly-arrived PR.

- [ ] **Step 5: Run changed-file context for non-target PRs in the workflow**

In `mobile_ios_qa_allocate.yml:174-185`, remove (or invert) the conditional that skips the context-fetch step for non-target PRs. Each PR in the queue must be checked for relevant file changes, not only the one currently being scheduled.

- [ ] **Step 6: Re-run tests**

```bash
cd scripts && python -m pytest test_ios_qa_slots.py -v
```

Expected: PASS.

- [ ] **Step 7: Lint workflow YAML**

```bash
yamllint .github/workflows/mobile_ios_qa_allocate.yml || true
```

(Don't block on lint warnings; just note them.)

- [ ] **Step 8: Commit**

```bash
git add scripts/ios_qa_slots.py scripts/test_ios_qa_slots.py .github/workflows/mobile_ios_qa_allocate.yml
git commit -m "fix(ci): preserve queued PRs in iOS QA slot allocator (PR #3440)"
```

- [ ] **Step 9: Push and comment**

```bash
git push origin HEAD:$(gh pr view 3440 --json headRefName -q .headRefName)
gh pr comment 3440 --body "Allocator now persists queued PR list across runs and runs changed-file context check for all PRs, not only the target. Added unit tests covering the case where a newer PR could previously jump an older queued PR and the case where a freed slot is filled from the head of the queue."
```

---

## Task 6: PR #3375 — l10n sweep for invites screen

**Files:**
- Modify: `mobile/lib/screens/invites/invites_screen.dart` (lines 37, 85, 100, 187, 235, 256 plus any others)
- Modify: `mobile/lib/l10n/app_en.arb`
- Generated: `mobile/lib/l10n/app_localizations*.dart` (codegen output)
- Test: any existing `mobile/test/screens/invites/...` widget tests that match literal strings

- [ ] **Step 1: Worktree + read intent**

```bash
gh pr checkout 3375 --detach
git worktree add ~/code/divine/divine-mobile-worktrees/pr-3375-invites-l10n pr-3375
cd ~/code/divine/divine-mobile-worktrees/pr-3375-invites-l10n
gh pr view 3375 --json title,body,files,reviews
```

- [ ] **Step 2: Identify all hardcoded strings**

```bash
grep -nE "Text\\(['\"]|Snackbar\\b|tooltip:" mobile/lib/screens/invites/invites_screen.dart
```

Confirm the lines flagged in review (37, 85, 100, 187, 235, 256) plus any others.

- [ ] **Step 3: Add ARB keys**

In `mobile/lib/l10n/app_en.arb`, add one key per string. Use snake-case ish camel keys (`invitesAwardedTitle`, `invitesEmptyStateMessage`, etc.) following the file's existing convention. Add `@key` metadata blocks with descriptions.

- [ ] **Step 4: Run l10n codegen**

```bash
cd mobile && mise exec -- flutter gen-l10n
```

Expected: regenerated `app_localizations*.dart` files. Confirm no errors.

- [ ] **Step 5: Replace hardcoded strings with `AppLocalizations.of(context)!.<key>`**

Update each call site in `invites_screen.dart`. Add the import if missing:

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

(Or whatever import path the rest of the codebase uses — match existing files.)

- [ ] **Step 6: Update widget tests that referenced literal strings**

```bash
grep -rnE "(Awarded|invite|Invite)" mobile/test/screens/invites/ || true
```

Update `find.text(...)` / `expect(find.text(...))` calls to read from the same ARB key, e.g. via a test helper or by pumping a `MaterialApp` with `AppLocalizations.delegate` and asserting on the resolved string.

- [ ] **Step 7: Analyze and run tests**

```bash
cd mobile && mise exec -- flutter analyze lib test
cd mobile && mise exec -- flutter test test/screens/invites
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/screens/invites mobile/lib/l10n mobile/test/screens/invites
git commit -m "chore(l10n): localize invites screen strings (PR #3375)"
```

- [ ] **Step 9: Push and comment**

```bash
git push origin HEAD:$(gh pr view 3375 --json headRefName -q .headRefName)
gh pr comment 3375 --body "Moved hardcoded strings in invites_screen.dart through app_en.arb and ran l10n codegen. Updated widget tests that referenced literal strings."
```

---

## Task 7: PR #3177 — l10n sweep for retry strings

**Files:**
- Modify: files surfaced by review for retry user-facing strings (publish primitives + repost retry feedback)
- Modify: `mobile/lib/l10n/app_en.arb`
- Generated: `mobile/lib/l10n/app_localizations*.dart`

- [ ] **Step 1: Worktree + read review comments to enumerate strings**

```bash
gh pr checkout 3177 --detach
git worktree add ~/code/divine/divine-mobile-worktrees/pr-3177-retry-l10n pr-3177
cd ~/code/divine/divine-mobile-worktrees/pr-3177-retry-l10n
gh pr view 3177 --json reviews,comments,title,body,files
```

Make a list of every hardcoded user-facing retry string flagged in review.

- [ ] **Step 2: Add ARB keys for each**

Add to `app_en.arb` with descriptive keys (`retryPublishFailedMessage`, `retryRepostQueuedMessage`, etc.). Include `@key` metadata.

- [ ] **Step 3: Run codegen**

```bash
cd mobile && mise exec -- flutter gen-l10n
```

- [ ] **Step 4: Replace each hardcoded string with the localized lookup**

Edit each call site identified in step 1.

- [ ] **Step 5: Analyze and run targeted tests**

```bash
cd mobile && mise exec -- flutter analyze lib test
cd mobile && mise exec -- flutter test <test paths for affected files>
```

- [ ] **Step 6: Commit**

```bash
git add mobile/lib mobile/test
git commit -m "chore(l10n): localize retry user-facing strings (PR #3177)"
```

- [ ] **Step 7: Push and comment**

```bash
git push origin HEAD:$(gh pr view 3177 --json headRefName -q .headRefName)
gh pr comment 3177 --body "Moved retry-related user-facing strings (publish primitives + repost retry feedback) through app_en.arb and ran codegen. Other review comments (unused nostr_client method, result type consistency) are out of scope for this commit and remain open."
```

---

## Task 8: PR #2878 — l10n sweep for C2PA import UI

**Files:**
- Modify: C2PA import flow widgets (TBD — discover during step 2)
- Modify: `mobile/lib/l10n/app_en.arb`
- Generated: `mobile/lib/l10n/app_localizations*.dart`

- [ ] **Step 1: Worktree + read intent**

```bash
gh pr checkout 2878 --detach
git worktree add ~/code/divine/divine-mobile-worktrees/pr-2878-c2pa-l10n pr-2878
cd ~/code/divine/divine-mobile-worktrees/pr-2878-c2pa-l10n
gh pr view 2878 --json reviews,comments,title,body,files
```

- [ ] **Step 2: Locate C2PA import widgets and enumerate hardcoded strings**

```bash
grep -rnE "Text\\(['\"]" mobile/lib --include='*.dart' | grep -i 'c2pa\\|import\\|verified' || true
```

Cross-reference with the PR diff to confirm the widgets owned by this PR.

- [ ] **Step 3: Add ARB keys**

Add to `app_en.arb` with import-flow-prefixed keys (`videoImportVerifiedTitle`, `videoImportFailedMessage`, etc.) and metadata.

- [ ] **Step 4: Run codegen**

```bash
cd mobile && mise exec -- flutter gen-l10n
```

- [ ] **Step 5: Replace hardcoded strings**

Edit each call site. Do **not** touch `video_import_service.dart:102` `proofManifestJson` issue — that is a separate defect outside this scope.

- [ ] **Step 6: Analyze and run targeted tests**

```bash
cd mobile && mise exec -- flutter analyze lib test
cd mobile && mise exec -- flutter test <relevant test paths>
```

- [ ] **Step 7: Commit**

```bash
git add mobile/lib mobile/test
git commit -m "chore(l10n): localize C2PA import UI strings (PR #2878)"
```

- [ ] **Step 8: Push and comment**

```bash
git push origin HEAD:$(gh pr view 2878 --json headRefName -q .headRefName)
gh pr comment 2878 --body "Moved C2PA import UI strings through app_en.arb. The proofManifestJson issue at video_import_service.dart:102 and the merge conflicts are out of scope for this commit and remain open."
```

---

## Task 9: Cross-PR cleanup

- [ ] **Step 1: Confirm no `uploadToken` log statements anywhere on `main`**

```bash
git fetch origin main
git switch -d origin/main
git grep -nE 'uploadToken' -- 'mobile/android' 'mobile/ios'
```

If any hits exist on `main` (independent of #3301), surface them and ask the user whether to file a follow-up.

- [ ] **Step 2: Summarize results to user**

Report: PRs where push succeeded; PRs where push fell back to a new PR; any flagged blockers (e.g. #3407 needing device QA, #3440 lint warnings).

- [ ] **Step 3: Remove all temporary worktrees**

```bash
for d in ~/code/divine/divine-mobile-worktrees/pr-*; do
  git worktree remove "$d" || true
done
```

- [ ] **Step 4: Mark all tasks complete and stop**

Do not extend scope to the out-of-scope PRs without explicit user approval.

---

## Notes for the executor

- Trust the spec, not assumptions. If a PR's actual code differs from the sketch in this plan (e.g. line numbers shifted, helpers renamed), **read the current code and adapt**. Do not paste the snippets in this plan verbatim if they don't match the file's reality.
- If a step's "expected" outcome doesn't match reality, stop and investigate. Don't paper over a failing test by changing the assertion.
- L10n codegen output is committed alongside ARB changes. Don't push without it.
- Keep commits focused per task. One commit per PR is the target; two if there's a clean separation between fix and tests.
- If you encounter merge conflicts that are not trivial (more than rebase-noise), stop and surface to the user — those are out of scope per the spec.
