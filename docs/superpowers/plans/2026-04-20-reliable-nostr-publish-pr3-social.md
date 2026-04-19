# Reliable Nostr Publish — PR 3: Social graph + interactions

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Depends on:** PR 1 merged.

**Goal:** Make every social-graph publish — follow set, follow-set deletion, comments, comment deletion, reactions (kind 7), reposts (kind 16), plus the generic base class — use `publishEventWithRetry` and surface `PublishOutcome`/`PublishUserFeedback` through the repositories/BLoCs that own these flows.

**Architecture:** The reactions and reposts path currently flows `Repository → NostrClient.sendLike/.deleteEvent → Nostr.sendLike/.sendRepost → sendEvent`. Those SDK helpers build the event then call `sendEvent` — they don't expose the outcome. We add `*AwaitOk` siblings in `NostrClient` that build the event locally (no dependency on the SDK helpers) and call `publishEventAwaitOk`. The `likes_repository` and `social_event_service_base` migrate to the new methods. Comments and follow sets in `comments_repository` + `social_service` call `publishEventWithRetry` directly.

---

## File Structure

### Created / Modified files

- Modify: `mobile/packages/nostr_client/lib/src/nostr_client.dart` — add `sendLikeAwaitOk`, `deleteEventAwaitOk`, `sendRepostAwaitOk`. Each builds the event via existing helpers then calls `publishEventAwaitOk`.
- Modify: `mobile/packages/likes_repository/lib/src/likes_repository.dart` — migrate the four `_nostrClient.sendLike` / `.deleteEvent` calls at `:233`, `:273`, `:345`, `:388`, plus the follow-on at `:714`/`:732`.
- Modify: `mobile/lib/services/social_service.dart:386` (kind 30000 follow set), `:514` (kind 5 follow-set deletion).
- Modify: `mobile/lib/services/base/social_event_service_base.dart:29` — the generic `broadcastAndCacheEvent` used by subclasses (reactions, reposts, generic social ops).
- Modify: `mobile/packages/comments_repository/lib/src/comments_repository.dart:265` (kind 1 comment) and `:404` (kind 5 comment deletion).
- Create: tests in each package / app test tree covering OK / reject / timeout paths.
- Modify: BLoCs / providers owning these flows — thread outcome + feedback through their state types.
- Modify: UI layers (comment list tile, follow button, like button, repost action sheet) — consume `feedback` for snackbars / disabled states.

---

## Chunk 1: `NostrClient` helpers for likes/reposts/deletions

### Task 1.1: `sendLikeAwaitOk`, `sendRepostAwaitOk`, `deleteEventAwaitOk`

**Background:** Today `NostrClient.sendLike`/`.deleteEvent` delegate to `nostr_sdk/Nostr.sendLike`/`.deleteEvent` which build the event then call `sendEvent`. The SDK helpers don't return a `PublishOutcome`, so we build the event in `nostr_client` ourselves and route through `publishEventAwaitOk`. That avoids modifying `nostr_sdk` while preserving the tag structure the SDK helpers produce.

- [ ] **Step 1: Write the failing tests**

Create `mobile/packages/nostr_client/test/src/send_like_await_ok_test.dart` and similar siblings. Cover:
- Like event is built with correct tags (`e`, `p`, optional `a`, optional `k`).
- Returns `PublishOutcome` from `publishEventAwaitOk`.
- Delete event is built with `e` tag and `"delete"` content.
- Repost event has `e` tag with optional relay hint.

- [ ] **Step 2: Verify fail**

Run: `cd mobile/packages/nostr_client && dart test test/src/send_like_await_ok_test.dart`

- [ ] **Step 3: Implement**

In `NostrClient`, add (example for `sendLikeAwaitOk`; sibling methods follow the same pattern):

```dart
Future<PublishOutcome> sendLikeAwaitOk({
  required String eventId,
  required String authorPubkey,
  String? addressableId,
  int? targetKind,
  String content = '+',
  RetryPolicy? policy,
  List<String>? targetRelays,
}) async {
  final tags = <List<String>>[
    ['e', eventId],
    ['p', authorPubkey],
    if (addressableId != null && addressableId.isNotEmpty) ['a', addressableId],
    if (targetKind != null) ['k', '$targetKind'],
  ];
  final event = Event(publicKey, EventKind.reaction, tags, content);
  await _nostr.signEvent(event);
  if (event.sig.isEmpty) {
    return PublishOutcome(
      eventId: event.id,
      acceptedBy: const {},
      rejectedBy: const {},
      noResponseFrom: const {},
    );
  }
  return policy == null
      ? publishEventAwaitOk(event, targetRelays: targetRelays)
      : publishEventWithRetry(event, policy: policy, targetRelays: targetRelays);
}

Future<PublishOutcome> deleteEventAwaitOk(
  String eventId, {
  RetryPolicy? policy,
  List<String>? targetRelays,
}) async {
  final event = Event(
    publicKey,
    EventKind.eventDeletion,
    [['e', eventId]],
    'delete',
  );
  await _nostr.signEvent(event);
  if (event.sig.isEmpty) {
    return PublishOutcome(eventId: event.id, acceptedBy: const {}, rejectedBy: const {}, noResponseFrom: const {});
  }
  return policy == null
      ? publishEventAwaitOk(event, targetRelays: targetRelays)
      : publishEventWithRetry(event, policy: policy, targetRelays: targetRelays);
}

Future<PublishOutcome> sendRepostAwaitOk({
  required String eventId,
  String? relayHint,
  String content = '',
  RetryPolicy? policy,
  List<String>? targetRelays,
}) async {
  final eTag = ['e', eventId, if (relayHint != null && relayHint.isNotEmpty) relayHint];
  final event = Event(publicKey, EventKind.repost, [eTag], content);
  await _nostr.signEvent(event);
  if (event.sig.isEmpty) {
    return PublishOutcome(eventId: event.id, acceptedBy: const {}, rejectedBy: const {}, noResponseFrom: const {});
  }
  return policy == null
      ? publishEventAwaitOk(event, targetRelays: targetRelays)
      : publishEventWithRetry(event, policy: policy, targetRelays: targetRelays);
}
```

- [ ] **Step 4: Run tests, commit**

```bash
git commit -m "feat(nostr_client): sendLike/deleteEvent/sendRepost AwaitOk variants"
```

---

## Chunk 2: `likes_repository` migration

### Task 2.1: Replace four `sendLike`/`deleteEvent` sites with `*AwaitOk` + retry

**Background:** `likes_repository.dart:233` (like), `:273` (unlike → sendLike with different tags), `:345` + `:388` (kind 5 reaction deletion), `:714`/`:732` (bookmark-style reaction). All are user-initiated, visible actions.

- [ ] **Step 1: Write failing repository test covering outcome threading**

`mobile/packages/likes_repository/test/src/likes_repository_reliability_test.dart`. Cover:
- Like succeeds (acceptedByAny) → repository returns `LikeResult.success(outcome)`.
- Like fails transient → repository returns `LikeResult.failure(outcome, feedback)`, retryable true.
- Unlike (deletion) fails permanent → retryable false; reason surfaces.
- Optimistic state is rolled back on failure (existing behavior; verify it still works with the new outcome contract).

- [ ] **Step 2: Migrate**

Change `LikesRepository` return types from `Event?` to a new `LikeResult` type that wraps `PublishOutcome` + `PublishUserFeedback`. Replace each `sendLike` / `deleteEvent` call with the `*AwaitOk` sibling.

- [ ] **Step 3: Update consuming BLoCs**

`LikeBloc` (or equivalent) — add `status`, `feedback` to state; on failure, expose feedback in state so the widget shows a snackbar/toast.

- [ ] **Step 4: Update UI**

Like button, repost button — on failure, show `PublishResultMapper.map(outcome)` snackbar with Retry action where retryable.

- [ ] **Step 5: Run tests, commit**

```bash
git commit -m "feat(likes): reliable like/unlike/repost via publishEventAwaitOk"
```

---

## Chunk 3: Comments (`comments_repository`)

### Task 3.1: Kind-1 comment publish + kind-5 comment deletion

Files: `mobile/packages/comments_repository/lib/src/comments_repository.dart:265`, `:404`.

- [ ] **Step 1: Write failing test**

`mobile/packages/comments_repository/test/src/comments_repository_reliability_test.dart`:
- Publishing a comment returns `CommentPublishResult` with outcome + feedback.
- Deleting a comment surfaces the deletion outcome.
- Optimistic UI insertion is rolled back when `outcome.failed`.

- [ ] **Step 2: Migrate**

```dart
final outcome = await _nostrClient.publishEventWithRetry(event);
final feedback = PublishResultMapper.map(outcome);
if (outcome.acceptedByAny) {
  return CommentPublishResult.success(comment: comment, outcome: outcome, feedback: feedback);
}
return CommentPublishResult.failure(outcome: outcome, feedback: feedback);
```

- [ ] **Step 3: UI wiring**

Locate the comment input / comment-list widget; show a "Couldn't post" snackbar with Retry on `feedback.retryable`. On failure, keep the draft text in the input so the user can retry without retyping.

- [ ] **Step 4: Tests and commit**

```bash
git commit -m "feat(comments): reliable comment publish + deletion"
```

---

## Chunk 4: Follow sets (`social_service.dart`)

### Task 4.1: Kind 30000 follow-set publish

`social_service.dart:386` — `addFollowSet`. Returns `Future<Event?>`; change to return a result wrapping outcome.

- [ ] **Step 1: Test**

`mobile/test/unit/services/social_service_reliability_test.dart`:
- Add-follow-set succeeds → state.followSets updated.
- Add-follow-set fails → state.followSets NOT updated, error feedback surfaced.
- Delete follow-set success / failure.

- [ ] **Step 2: Migrate**

Replace `publishEvent` at `:386` and `:514` with `publishEventWithRetry`. Move optimistic state update (adding to the local follow set map) to fire only after `outcome.acceptedByAny`.

- [ ] **Step 3: Locate BLoC/provider**

Grep for `addFollowSet` callers. Thread outcome/feedback through.

- [ ] **Step 4: UI wiring**

Follow button / follow-set manager widget — show snackbar on failure, disable optimistic "following" check until outcome resolves.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(social): reliable follow-set publish + deletion"
```

---

## Chunk 5: Generic `SocialEventServiceBase`

### Task 5.1: `broadcastAndCacheEvent`

`base/social_event_service_base.dart:29` — used by every service that does ad-hoc broadcasts (reactions wrapper, small social ops). The base method signature is `Future<Event?> broadcastAndCacheEvent(Event event)`. Change to return `Future<PublishOutcome>`.

- [ ] **Step 1: Audit subclasses**

Grep for overrides and callers. Each subclass may need its own result type update.

- [ ] **Step 2: Test base behavior**

Add `test/unit/services/base/social_event_service_base_test.dart` covering the return-type change and outcome threading.

- [ ] **Step 3: Migrate base + subclasses**

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(social-base): broadcastAndCacheEvent returns PublishOutcome"
```

---

## Chunk 6: Verification

- [ ] **Step 1: Analyzer + tests**

```bash
cd mobile && flutter analyze lib test
(cd mobile/packages/nostr_client && dart analyze && dart test)
(cd mobile/packages/likes_repository && dart analyze && dart test)
(cd mobile/packages/comments_repository && dart analyze && dart test)
```

- [ ] **Step 2: Integration test**

`mobile/test/integration/e2e/` has end-to-end flows that exercise commenting/reacting; run those against the local Docker stack.

- [ ] **Step 3: Open PR**

Title: `feat(social): reliable follow/comment/reaction/repost publishing`

PR body notes:
- Adds `sendLike/deleteEvent/sendRepostAwaitOk` to `NostrClient` so the existing callers can get a `PublishOutcome`.
- Migrates `likes_repository`, `comments_repository`, `social_service`, `SocialEventServiceBase`.
- Optimistic UI updates now gated behind `outcome.acceptedByAny` — fixes the "liked but the relay never heard about it" ghost-like bug.

---

## Risks

- **Optimistic like/unlike pattern.** Users expect instant UI feedback. Keep the visual toggle instant but roll back on failure (matching the existing `likes_repository` behavior). Verify the rollback path under `PublishResultMapper` error cases.
- **Scope creep in `SocialEventServiceBase`.** Change the base return type in a single commit; subclass fan-out is the next commit. Keep each commit reviewable.
- **Comments optimistic insertion.** Keep the draft text on failure so the user isn't punished for a flaky relay.
