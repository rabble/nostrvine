# Popular Feed Reliability - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (or subagent-driven-development) to implement this plan task-by-task.

**Goal:** Fix the "Popular Now" feed staying empty by fixing subscription timeout handling and implementing a "Cache-First + Gateway" hybrid strategy for faster, resilient loading.

**Architecture:** 
1.  **Bug Fix:** Update `VideoEventService` to clear `_activeSubscriptions` when a WebSocket subscription times out with 0 events. This allows retries.
2.  **Hybrid Loading:** Modify `VideoEventService` to query the Divine REST Gateway (via `NostrClient.queryEvents`) in parallel with the WebSocket subscription for public feeds. Merges results, deduplicating by event ID.

**Tech Stack:** Dart, Riverpod, Nostr Protocol (WebSocket + REST Gateway)

---

### Task 1: Reproduce Timeout Bug & Fix

**Files:**
- Create: `test/services/video_event_service_timeout_test.dart`
- Modify: `lib/services/video_event_service.dart`

**Step 1: Write failing test for timeout behavior**

Create a test using `fake_async` that simulates a 30s timeout with no events.
- Assert that `_activeSubscriptions` still contains the subscription ID (the bug).
- Assert that calling `subscribe` again sends NO request to `NostrClient` (because it thinks it's active).

**Step 2: Run test to verify it fails**

Run: `flutter test test/services/video_event_service_timeout_test.dart`
Expected: FAIL (Subscription remains active, retries blocked)

**Step 3: Implement timeout cleanup**

Modify `lib/services/video_event_service.dart`:
- In the `feedLoadingTimeout` callback (around line 1205):
- Add cleanup logic similar to `onDone` handler: `_activeSubscriptions.remove(subscriptionType);`

**Step 4: Update test to verify cleanup**

Update the test to assert `_activeSubscriptions` is empty after timeout.
Call `subscribe` again and verify `mockNostrClient.subscribe` IS called.

**Step 5: Run test to verify it passes**

Run: `flutter test test/services/video_event_service_timeout_test.dart`
Expected: PASS

**Step 6: Commit**

```bash
git add lib/services/video_event_service.dart test/services/video_event_service_timeout_test.dart
git commit -m "fix: clear active subscriptions on feed loading timeout so retries are possible"
```

---

### Task 2: Implement Gateway Integration

**Files:**
- Modify: `lib/services/video_event_service.dart`
- Create: `test/services/video_event_service_gateway_test.dart`

**Step 1: Write test for gateway integration**

Create a test that:
- Mocks `NostrClient.queryEvents` to return a list of specific "Gateway Events".
- Calls `subscribeToVideoFeed(subscriptionType: SubscriptionType.popularNow)`.
- Verifies that `queryEvents` was called with `useGateway: true`.
- Verifies "Gateway Events" are present in the service's event list immediately.

**Step 2: Run test to verify it fails**

Run: `flutter test test/services/video_event_service_gateway_test.dart`
Expected: FAIL (Gateway not queried)

**Step 3: Implement gateway query logic**

Modify `lib/services/video_event_service.dart`:
1.  Add private helper `_shouldUseGatewayForFeed(SubscriptionType type)`.
    - Types: `popularNow`, `discovery`, `trending`, `hashtag`.
2.  Add `_queryGatewayAndMerge` method.
    - Extract the *single* primary video filter (ignore repost filter).
    - Call `_nostrService.queryEvents` (unawaited).
    - Process results via `_handleNewVideoEvent`.
3.  Call `_queryGatewayAndMerge` in `subscribeToVideoFeed` just after the local cache load.

**Step 4: Run test to verify it passes**

Run: `flutter test test/services/video_event_service_gateway_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/services/video_event_service.dart test/services/video_event_service_gateway_test.dart
git commit -m "feat: query REST gateway for public feeds (Popular, Explore) for instant loading"
```

---

### Task 3: verify Fixes

**Step 1: Run all VideoEventService tests**

Ensure no regressions in existing logic.

Run: `flutter test test/services/video_event_service*_test.dart`

**Step 2: Commit**

```bash
git commit --allow-empty -m "chore: verify video event service tests pass"
```
