# DM Scaling Fix — Design

**Date:** 2026-04-05
**Status:** Approved, pending implementation plan
**Owner:** @rabble

## Problem

`DmRepository` (`mobile/lib/repositories/dm_repository.dart`) opens a NIP-17 gift-wrap subscription at app startup and keeps a 10-second poller running for the life of the process. The subscription filter has no `since:` bound, so every cold start replays the **entire** gift-wrap history for the user's pubkey. Each event is processed sequentially through an event lock on the UI isolate, with per-event debug logs and synchronous SQLite dedup lookups.

### Observed symptoms
- Startup log spam: hundreds of `Received gift wrap event…` / `Skipping duplicate gift wrap…` lines per second on cold start.
- UI isolate contention during the first several seconds of app life — home feed competes with DM replay.
- All DM work (subscription, decryption, logging) happens regardless of whether the user ever opens the messages tab.

### Projected symptoms at scale
- Linear-in-total-DM-count cold-start cost. At ~10k DMs the startup stall becomes measured in tens of seconds.
- iOS watchdog termination risk on cold start past the 20-second launch budget.
- New-device installs re-decrypt the entire backlog on the main isolate (minutes of CPU work).
- Cross-protocol dedup (`hasMatchingMessage`, ±5s timestamp window) grows slower and risks false-positive message collapse as volume grows.

### Source-of-spam references
- `mobile/lib/repositories/dm_repository.dart:150` — `initialize()` calls `startListening()` unconditionally.
- `mobile/lib/repositories/dm_repository.dart:206–260` — `startListening()` opens subscription + starts poller.
- `mobile/lib/repositories/dm_repository.dart:404, 412, 468` — the three debug log lines.
- `mobile/lib/repositories/dm_repository.dart:259` — `_startPolling()`, 10-second interval with `limit: 20`.
- `mobile/lib/repositories/dm_repository.dart:424` — NIP-17 three-layer decryption on the UI isolate.

## Goals

1. Cold start does zero DM work. No subscription, no decryption, no logging until the user visits the messages tab.
2. DM sync cost is bounded by user behavior, not by total lifetime message count.
3. Decryption never blocks the UI isolate.
4. Existing local data is preserved; no destructive migration.
5. Messaging UX remains correct: new messages appear while the inbox is open, history is reachable on demand.

## Non-goals

- Background push notifications (infrastructure does not exist yet).
- In-app "you have new messages" indicator outside the inbox tab (separate UI task).
- Migrating or pruning existing local DM storage.
- Replacing NIP-04 legacy support.

## Design

### 1. Lifecycle — subscription gated by inbox visibility

`DmRepository.initialize()` stops opening the subscription. Two new methods take over:

- `Future<void> openInbox()` — idempotent. Starts the gift-wrap subscription, kicks off the initial sync, returns when the first page of 50 events is processed (or on timeout/empty result).
- `Future<void> closeInbox()` — idempotent. Tears down the subscription, cancels any in-flight sync, drains the decrypt isolate queue.

Called from the messages tab screen's BLoC on open/close and from app lifecycle hooks when the app backgrounds. `initialize()` still runs at app start to wire up DB handles, decryptor instances, and prefs — but emits no network traffic and runs no gift-wrap processing.

### 2. Sync strategy — count-based windowing

Two persisted keys in user prefs, scoped per-pubkey:
- `dm.newestSyncedAt` — the highest `created_at` we have successfully processed.
- `dm.oldestSyncedAt` — the lowest `created_at` we have successfully processed.

**First inbox open (no `newestSyncedAt`):**
- Subscribe with filter `{kinds:[1059, 4, 5], p:[me], limit: 50}`.
- Stream incoming events into a bounded queue.
- Batch decryption (see §3).
- On EOSE or after 50 events are processed, record `newestSyncedAt` and `oldestSyncedAt`, and transition to "steady" mode.
- Live subscription stays open while inbox is visible; new events stream in.

**Subsequent inbox opens:**
- Subscribe with filter `{kinds:[1059, 4, 5], p:[me], since: newestSyncedAt - 2*86400}`. The 2-day overlap absorbs NIP-17 timestamp jitter (spec allows ±2 day randomization).
- Local SQLite dedup absorbs the overlap cleanly (already works).
- `newestSyncedAt` advances as events are processed.

**"Load older" pagination:**
- Triggered by scroll-to-top on the conversation list, or by a user-facing "Load older" control.
- Fetch `{kinds:[1059, 4, 5], p:[me], until: oldestSyncedAt, limit: 50}`.
- Update `oldestSyncedAt` as the page completes.
- Repeat on subsequent "load older" actions.

**Per-conversation "load older":**
- Gift wraps hide sender, so we cannot filter server-side by conversation. v1 reuses the global "load older" page and filters client-side. Acceptable because the conversation list drives ordering; users loading more in a specific conversation typically also benefit from seeing older messages globally. Revisit in v2 if needed.

### 3. Decryption isolate

New file: `mobile/lib/repositories/dm_decryption_worker.dart`.

```dart
// Top-level function runnable under compute().
Future<List<DecryptedRumorResult>> decryptGiftWrapBatch(
  DecryptBatchRequest request,
);
```

`DecryptBatchRequest` carries a `List<RawGiftWrapEvent>` and the user's private key bytes. `DecryptedRumorResult` carries the rumor plus any per-event error so the caller can log failures on the main isolate without the worker owning any logging infrastructure.

**Flow inside `DmRepository`:**
1. Subscription delivers an event on the main isolate.
2. Main isolate runs `hasGiftWrap(id)` — cheap indexed lookup. If already stored, drop it silently.
3. New events are accumulated into a batch of ~10 or flushed on a 250ms timer, whichever comes first.
4. Each batch is handed to `compute(decryptGiftWrapBatch, request)`.
5. Results come back to the main isolate, which runs the existing `hasMatchingMessage` cross-protocol dedup + writes to `messages`/`conversations` tables in a single transaction per batch.

The private key crosses the isolate boundary once per batch. Acceptable: batches only run while the inbox is open, and the key is already in memory on the main isolate.

### 4. Kill the poller, cut the logs

- **Delete `_startPolling()` and its timer.** The WebSocket subscription is live while the inbox is open; polling a live subscription is pure waste.
- **Delete the three `Log.debug` calls at dm_repository.dart:404, 412, 468.** They were useful during bring-up and are now a measurable cost during replay. If deeper debugging is ever needed, gate a new log behind `assert(() { ... return true; }())` or a `kDebugMode && _verboseDmLogging` const so the hex-id interpolation itself doesn't run in release builds.

### 5. Data compatibility

No schema changes. No migration. Existing `gift_wraps`, `messages`, `conversations`, `nip04_messages` tables stay as they are. The new `newestSyncedAt` / `oldestSyncedAt` prefs start null on upgrade, which correctly routes the first post-upgrade inbox open into the "first open" path — but because local data already exists, the per-event dedup skip is fast and nothing re-decrypts.

### 6. Testing strategy

**Unit tests — `DmRepository`:**
- `initialize()` does not open a subscription and does not call the relay client.
- `openInbox()` opens exactly one subscription and returns when the first page is processed.
- `closeInbox()` cancels the subscription and drains pending batches.
- `openInbox(); closeInbox(); openInbox();` yields exactly two subscription lifecycles with no leaks.
- First-open vs subsequent-open select the correct filter (presence/absence of `since:`).
- Pagination advances `oldestSyncedAt` monotonically.

**Unit tests — `dm_decryption_worker`:**
- Empty batch returns empty result.
- Malformed event returns an error entry, not a crash; other events in the batch succeed.
- Results preserve input order.
- Bad private key surfaces as a structured error.

**Unit tests — messages tab BLoC / owner widget:**
- Mounts `openInbox`, disposes `closeInbox`.
- App backgrounding triggers `closeInbox`; foregrounding while inbox visible triggers `openInbox`.

**Integration test:**
- Seeded local DB with N fake gift wraps + mock relay.
- Cold-start app, navigate through feed, assert `DmRepository` subscription count is 0 and `hasGiftWrap` call count is 0.
- Tap messages tab, assert exactly one subscription is opened and results render.

**Micro-benchmark / regression guard:**
- Measure `runApp -> first frame` with a seeded DB of 1000 gift wraps, before and after. Post-change number should be independent of the seed size.

## Open questions / v2 candidates

- Per-conversation `since:` pagination would need a side index (`conversation_id -> oldest_synced_at`). Revisit if client-side filtering of load-older pages proves insufficient.
- An unread-count badge outside the inbox tab requires either background subscription or server-side push. Out of scope for this design, but the lifecycle split here makes either approach cleanly pluggable later.
- Consider a one-time background compaction pass to drop cross-protocol dedup's ±5s window for records where we have confident NIP-17 provenance, to eliminate false-positive risk at scale.

## Rollout

Single PR, feature branch off main, isolated worktree. No feature flag — the behavior change is correct regardless of scale and only improves cold-start performance. Pre-merge manual QA: open inbox on an account with meaningful history, verify conversation list populates and live messages arrive, verify "load older" works, verify closing and reopening the tab doesn't leak subscriptions.
