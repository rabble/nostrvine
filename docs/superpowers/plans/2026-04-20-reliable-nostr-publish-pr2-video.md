# Reliable Nostr Publish — PR 2: Video publishing

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Depends on:** PR 1 (`feat/reliable-nostr-publish`) merged. This plan uses `NostrClient.publishEventWithRetry`, `PublishOutcome`, and `PublishResultMapper` from PR 1.

**Goal:** Migrate the two video publishing entry points — initial publish (kind 34236) and the rebroadcast/edit path — to `publishEventWithRetry`, delete the ad-hoc 3x retry loop in `video_event_publisher.dart`, and surface failure states the BLoC/UI can render.

**Architecture:** Video publishing already has two pieces of ad-hoc reliability logic:
- `video_event_publisher.dart:898-934` — 3x retry with fire-and-forget intermediate retries.
- `video_event_publisher.dart:239-256` — signed-event persistence for resumable publishes across app restarts.

We delete the retry loop (superseded by `publishEventWithRetry`) but **keep** the resumable-signed-event cache — it addresses a different problem (app kill → resume) that retry doesn't solve.

**Tech Stack:** Dart/Flutter, `nostr_client` (PR 1), Riverpod (video publish providers), BLoC (rebroadcast flow in `share_video_menu.dart` where applicable).

---

## File Structure

### Modified files

- `mobile/lib/services/video_event_publisher.dart` — replace `publishEvent` at `:209` with `publishEventWithRetry`; delete the retry wrapper at `:898-934`; surface `PublishOutcome` on the publisher's result type.
- `mobile/lib/widgets/share_video_menu.dart` — replace the rebroadcast `publishEvent` at `:1709` with `publishEventWithRetry`; show retry-able snackbar on transient failure (mirror the delete flow from PR 1).
- `mobile/lib/providers/video_publish_state.dart` (or equivalent — locate the state type returned by the publisher) — add `outcome` + `feedback` fields.

### Created/updated tests

- `mobile/test/unit/services/video_event_publisher_reliability_test.dart` — new file covering OK / reject / timeout / retry behavior via mocked `NostrClient.publishEventWithRetry`.
- `mobile/test/widgets/share_video_menu_edit_test.dart` — extend (or create) to cover the rebroadcast retry UX.

---

## Chunk 1: Migrate `video_event_publisher.dart`

### Task 1.1: Replace `publishEvent` + retry loop

**Background:** The current flow at `:209` calls `_nostrService.publishEvent(event)` inside a custom retry helper at `:898`. Video publishing is the most user-visible publish in the app — a silent failure here means the creator thinks their video uploaded when it's reachable from zero relays.

- [ ] **Step 1: Write failing unit test**

Create `mobile/test/unit/services/video_event_publisher_reliability_test.dart`:

```dart
// ABOUTME: Tests video publishing wraps NostrClient.publishEventWithRetry and
// ABOUTME: surfaces outcome+feedback on its result type.

// - stub publishEventWithRetry with accepted-by-any → publisher reports success
// - stub with all-no-response → publisher reports retryable failure
// - stub with permanent rejection → publisher reports non-retryable failure
// - verify the ad-hoc 3x retry loop is NOT invoked (publishEventWithRetry owns it)
```

Cover these scenarios explicitly:
1. First-attempt success.
2. Transient failure → `publishEventWithRetry` returns non-retryable after `maxAttempts`. Publisher propagates `outcome.failed` + `feedback.retryable`.
3. Permanent rejection (e.g. `blocked: duplicate`). Publisher propagates the reason via `feedback.firstRejectionReason`.
4. Signed-event persistence cache is still written (resumable-publish behavior preserved).

- [ ] **Step 2: Verify fail**

Run: `cd mobile && flutter test test/unit/services/video_event_publisher_reliability_test.dart`

- [ ] **Step 3: Update the publisher**

In `video_event_publisher.dart` around `:200-260`:

```dart
final outcome = await _nostrService.publishEventWithRetry(
  event,
  policy: const RetryPolicy(maxAttempts: 3, timeoutPerAttempt: Duration(seconds: 15)),
);
final feedback = PublishResultMapper.map(outcome);

if (outcome.acceptedByAny) {
  Log.info('Video publish accepted: relays=${outcome.acceptedBy}', name: 'VideoEventPublisher');
  await _clearRetryableSignedEvent(event.id); // resumable cache cleanup
  return VideoPublishResult.success(outcome: outcome, feedback: feedback, eventId: event.id);
}

Log.error('Video publish failed: $outcome', name: 'VideoEventPublisher');
// KEEP the signed event cached so the user can retry after app restart.
return VideoPublishResult.failure(outcome: outcome, feedback: feedback);
```

- [ ] **Step 4: Delete the ad-hoc retry loop at `:898-934`**

That logic is now handled by `publishEventWithRetry`. Remove the helper and its call site. Do NOT remove `_loadRetryableSignedEvent` / `_persistRetryableSignedEvent` — those are resumable-publish caching, a different concern.

- [ ] **Step 5: Run tests**

Run: `cd mobile && flutter test test/unit/services/video_event_publisher_reliability_test.dart`
Expected: PASS.

- [ ] **Step 6: Run the existing publisher test suite for regressions**

Run: `cd mobile && flutter test test/unit/services/video_event_publisher_test.dart`
Fix any test that asserts the old 3x loop; update to assert `publishEventWithRetry` is called once.

- [ ] **Step 7: Commit**

```bash
git commit -m "feat(video-publish): publishEventWithRetry replaces ad-hoc retry loop"
```

### Task 1.2: Update the BLoC/provider consuming the publisher

- [ ] **Step 1: Locate the state type**

Grep for `VideoPublishResult` / `videoPublishStateProvider` / similar in `mobile/lib/blocs/` and `mobile/lib/providers/`. Add `PublishOutcome? outcome` and `PublishUserFeedback? feedback` fields to the success and failure states.

- [ ] **Step 2: Update state tests**

Ensure the state class's test (`test/blocs/video_publish_bloc_test.dart` or `providers/video_publish_provider_test.dart`) covers the new fields.

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(video-publish): thread PublishOutcome through publish state"
```

---

## Chunk 2: Migrate the rebroadcast flow in `share_video_menu.dart`

### Task 2.1: Rebroadcast with retry + UX

**Background:** When a user edits a video's description/tags, `_updateVideo` at `share_video_menu.dart:1696` creates a new kind-34236 event with `createdAt + 1` so relays treat it as a replacement. Today's code calls `publishEvent` and ignores the result — showing "Video updated successfully" regardless. A failed publish means the original video stays visible in every feed, but the user thinks it updated.

- [ ] **Step 1: Write the failing widget test**

Create/extend `mobile/test/widgets/share_video_menu_edit_test.dart`:

```dart
// Covers three paths:
// 1. publishEventWithRetry returns accepted → shows green "Video updated" SnackBar.
// 2. Returns all-no-response → shows red retryable SnackBar with Retry action.
//    Tapping Retry re-invokes publishEventWithRetry.
// 3. Returns permanent rejection → shows red NON-retryable SnackBar.
```

- [ ] **Step 2: Update the widget**

Replace the publish block in `_updateVideo`:

```dart
final outcome = await nostrService.publishEventWithRetry(event);
final feedback = PublishResultMapper.map(outcome);

if (!mounted) return;

if (outcome.acceptedByAny) {
  // Only update local cache after confirmed publish.
  ref.read(personalEventCacheServiceProvider).cacheUserEvent(event);
  ref.read(videoEventServiceProvider).updateVideoEvent(VideoEvent.fromNostrEvent(event));

  context.pop();
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Video updated successfully'),
      backgroundColor: VineTheme.vineGreen,
    ),
  );
  return;
}

setState(() => _isUpdating = false);
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(_copyForFeedback(feedback)),
    backgroundColor: VineTheme.error,
    action: feedback.retryable
        ? SnackBarAction(label: 'Retry', onPressed: _updateVideo)
        : null,
  ),
);
```

Reuse the `_copyForFeedback` helper introduced in PR 1.

Note: **do not update the local cache before `outcome.acceptedByAny`.** The old code cached unconditionally, so a failed publish silently presented the edit as successful in every feed. Move the cache writes inside the acceptance branch.

- [ ] **Step 3: Run widget test**

Run: `cd mobile && flutter test test/widgets/share_video_menu_edit_test.dart`
Expected: PASS.

- [ ] **Step 4: Manual smoke test**

Edit a video description while pointed at a local stack relay that's configured to drop OK frames → expect retry snackbar. Edit against a relay that rejects with `blocked: duplicate` → expect non-retryable snackbar with reason.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(video-rebroadcast): publishEventWithRetry + retry snackbar in edit flow"
```

---

## Chunk 3: Verification and PR

- [ ] **Step 1: Analyzer**

Run: `cd mobile && flutter analyze lib test`. Zero issues.

- [ ] **Step 2: Test suite**

Run: `cd mobile && flutter test test/unit/services/video_event_publisher_reliability_test.dart test/widgets/share_video_menu_edit_test.dart`

- [ ] **Step 3: Integration smoke test**

Run the upload E2E that exists at `mobile/test/integration/upload_publish_e2e_comprehensive_test.dart` against the local Docker stack:

```bash
cd mobile && mise run e2e_test integration_test/e2e/video_creation_test.dart
```

- [ ] **Step 4: Push & open PR**

Title: `feat(video-publish): reliable publish + rebroadcast via publishEventWithRetry`

Body highlights:
- Replaces the 3x ad-hoc retry in `video_event_publisher.dart` with `publishEventWithRetry`.
- Moves local-cache writes in `share_video_menu.dart` inside the acceptance branch — prevents ghost-update bug where a failed rebroadcast still looked updated locally.
- Resumable-signed-event cache preserved — handles a different failure mode (app kill during publish).

---

## Risks

- **Resumable-signed-event cache interaction.** Retry lives in-memory; resumable cache is across app restarts. Preserve both — different layers of durability.
- **Rebroadcast treated as replacement by relays.** The existing `createdAt + 1` trick is unchanged; PR 2 does not alter the event shape.
- **E2E tests depend on local Docker stack.** Document in PR that the video E2E needs `mise run local_up` before running locally.
