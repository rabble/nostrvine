# Reliable Nostr Publish — PR 7: Account deletion (NIP-62)

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Depends on:** PR 1 merged.

**Goal:** Give account deletion the strongest possible reliability guarantees in the app. A user who asks to delete their account expects every event they ever signed to be deletion-requested. Today, a silent failure in any relay leaves content reachable, and worst case a full-batch failure means the account deletion "completed" locally while not a single relay heard about it.

**Architecture:** `account_deletion_service.dart` does two things in sequence:
1. Publish a kind-62 NIP-62 account-deletion event (`:104`).
2. Loop through the user's events and publish kind-5 deletions for each (`:188` — `_publishDeletionEventsForAll`).

Both call `_nostrService.publishEvent`. We migrate both to `publishEventWithRetry`, surface progress through a dedicated state type, and add a "stuck" escape hatch: if after all retries the NIP-62 event never lands on **any** relay, the UI offers the user a last-chance retry rather than silently claiming success.

---

## File Structure

### Modified

- `mobile/lib/services/account_deletion_service.dart:104` — NIP-62 event.
- `mobile/lib/services/account_deletion_service.dart:188` — batch kind-5 loop.
- `AccountDeletionBloc` / provider — expose per-item status, overall progress.
- Account settings → Delete Account screen — real-time progress + per-event error surfacing.

### Tests (created)

- `mobile/test/unit/services/account_deletion_service_reliability_test.dart`
- `mobile/test/blocs/account_deletion_bloc_test.dart`
- `mobile/test/integration/account_deletion_flow_test.dart` (existing — update with new contract).

---

## Chunk 1: NIP-62 event publishing

### Task 1.1: Migrate `deleteAccount`

**Background:** The kind-62 event is the canonical signal to downstream indexers/clients that this account has been deleted. If it never lands, indexers still surface the account's content.

- [ ] **Step 1: Write failing test**

`mobile/test/unit/services/account_deletion_service_reliability_test.dart`:
- Success path.
- Transient failure → retried by policy; final outcome.failed surfaces.
- Permanent rejection → immediate non-retryable failure.

- [ ] **Step 2: Migrate**

```dart
final outcome = await _nostrService.publishEventWithRetry(
  event,
  policy: const RetryPolicy(
    maxAttempts: 5, // higher than default — account deletion is high-stakes
    timeoutPerAttempt: Duration(seconds: 20),
  ),
);
final feedback = PublishResultMapper.map(outcome);

if (!outcome.acceptedByAny) {
  Log.error('NIP-62 publish failed, aborting account deletion flow: $outcome');
  return AccountDeletionResult.nip62Failure(outcome: outcome, feedback: feedback);
}

// Proceed to batch kind-5 deletions only if the NIP-62 event landed.
```

**Key contract change:** do NOT start the kind-5 batch if the NIP-62 event failed. Today the code proceeds regardless — leading to a state where some events have deletion requests but the authoritative NIP-62 signal is missing.

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(account-deletion): reliable NIP-62 publish with abort-on-failure"
```

---

## Chunk 2: Batch kind-5 deletion loop

### Task 2.1: Per-event retry with progress reporting

**Background:** `_publishDeletionEventsForAll` at `:188` loops over every user event and publishes a kind-5 deletion. On a user with thousands of events, serial retry on each is slow; parallel retry risks relay rate-limits. Design: parallel with a concurrency cap (default 4 in-flight), each event publishing via `publishEventWithRetry`.

- [ ] **Step 1: Test**

Cover:
- All events publish successfully → progress reaches 100%, result reports all-success.
- Some events fail transient → reported as `failedEventIds` in result with per-event feedback.
- Some permanent rejections → similar, separated by retryable flag.
- Cancellation: user aborts mid-flow → no new publishes dispatched, current in-flight ones allowed to finish.

- [ ] **Step 2: Implement concurrency-capped parallel loop**

Use a simple pool pattern (no new dependency):

```dart
Future<BatchDeletionResult> _publishDeletionEventsForAll(
  List<Event> userEvents, {
  int concurrency = 4,
  void Function(int completed, int total)? onProgress,
}) async {
  final results = <String, PublishOutcome>{};
  final feedbacks = <String, PublishUserFeedback>{};
  final queue = List<Event>.from(userEvents);
  var completed = 0;

  Future<void> worker() async {
    while (queue.isNotEmpty) {
      final event = queue.removeAt(0);
      final outcome = await _nostrService.publishEventWithRetry(event);
      results[event.id] = outcome;
      feedbacks[event.id] = PublishResultMapper.map(outcome);
      completed++;
      onProgress?.call(completed, userEvents.length);
    }
  }

  await Future.wait(List.generate(concurrency, (_) => worker()));

  final succeeded = results.entries.where((e) => e.value.acceptedByAny).map((e) => e.key).toSet();
  final failed = results.keys.toSet().difference(succeeded);
  return BatchDeletionResult(
    succeededEventIds: succeeded,
    failedEventIds: failed,
    feedbacks: feedbacks,
  );
}
```

- [ ] **Step 3: BLoC wiring**

`AccountDeletionBloc` state shows overall progress (e.g. `progress: 0.45` for 45% done) and a list of per-event failures surfaced after completion.

- [ ] **Step 4: UI**

Delete Account screen progress view:
- Linear progress indicator driven by `state.progress`.
- On completion: summary panel with "N of M deletion requests published, K failed (retry)". A `Retry failed` button re-runs the batch with only the failed event IDs.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(account-deletion): parallel kind-5 batch with per-event outcome tracking"
```

---

## Chunk 3: Integration test refresh

### Task 3.1: Update `test/integration/account_deletion_flow_test.dart`

**Background:** The existing integration test was written against the silent-success contract. Update it to assert:
- On all-relay failure for NIP-62, the flow aborts before issuing kind-5 deletions.
- On partial failure of kind-5 batch, result reports which event IDs are still undeleted.
- The "Retry failed" button re-runs only the failed subset.

- [ ] **Step 1: Update test**

- [ ] **Step 2: Run against the local stack**

`mise run local_up && cd mobile && flutter test test/integration/account_deletion_flow_test.dart`

- [ ] **Step 3: Commit**

```bash
git commit -m "test(account-deletion): update integration test for reliable publish contract"
```

---

## Chunk 4: Verification and PR

- [ ] **Step 1: Analyzer + unit + integration tests**

- [ ] **Step 2: Manual smoke test**

Against local stack:
- Create a test account with ~20 videos.
- Kill one relay mid-deletion. Verify the UI surfaces which event IDs failed.
- Tap Retry failed → verify the retry runs only on the remaining event IDs.

- [ ] **Step 3: Open PR**

Title: `feat(account-deletion): reliable NIP-62 + parallel kind-5 batch`

Body:
- NIP-62 event now uses a 5-attempt retry policy; flow aborts if the kind-62 event never lands (previously proceeded silently).
- Kind-5 batch runs parallel (concurrency 4) with per-event outcome tracking.
- UI shows real-time progress and lets the user retry failed subset.

---

## Risks

- **User cancellation mid-batch.** Must not leave the publisher in a bad state. Use a cancellation token; in-flight publishes finish naturally, new ones are skipped.
- **Rate limiting on burst deletion.** 4-way concurrency is conservative. If relays rate-limit, `rate-limited:` prefix is a permanent rejection per NIP-01 so no infinite retry. A follow-up could add per-relay throttling, but out of scope for this PR.
- **Local account state.** Existing code clears local auth/keys after the flow. Keep that behavior, but only after the NIP-62 event lands (consistent with the abort-on-nip62-failure rule).
- **Partial success visibility.** Users should see "Your account deletion was requested. 18 of 20 events published successfully; 2 can be retried." — concrete numbers, not "mostly succeeded".
