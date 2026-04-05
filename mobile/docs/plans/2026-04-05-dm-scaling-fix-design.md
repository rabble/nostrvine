# DM Cold-Start Scaling Fix — Design

**Date**: 2026-04-05
**Status**: Approved
**Issue**: #2766

## Problem Statement

`DmRepository.initialize()` opens a NIP-17 gift-wrap relay subscription at app
startup and keeps a 10-second poller running for the life of the process. The
subscription filter has no `since:` bound, so **every cold start replays the
entire gift-wrap history** for the user's pubkey on the UI isolate.

The cost is **linear in lifetime DM count**, not recent activity:

| Lifetime DMs | Symptom |
|---|---|
| ~1 k | Cold start visibly janky, 2–5 s stutter |
| ~5 k | 10 s+ stall, scroll-on-launch broken |
| ~10 k | Minutes on new-device install; SQLite bloat |
| ~25 k+ | iOS watchdog termination (20 s budget) — **crash on startup** |

The 10-second poller amplifies the problem while idle: ~172 800 redundant dedup
lookups per day per user, plus log spam, plus main-isolate contention — whether
or not the user opens messages.

### Root Cause (one sentence)

There is no concept of "I've already synced up to timestamp T"; the system
trusts SQLite dedup to make full-backlog replay idempotent, which hides an
O(total_history) cost behind every cold start and every reinstall.

## Current Pipeline (broken)

```
App launch
  → isNostrReadyProvider becomes true
    → dmRepositoryProvider calls repository.initialize()
      → startListening()                         ← NO since: filter
        → relay replays ALL stored gift wraps
        → _startPolling() kicks off 10 s timer   ← runs FOREVER
      → _mergeDuplicateConversations()           ← loads ALL conversations
```

Every incoming event serializes through `_eventLock` on the UI isolate, runs a
SQLite dedup lookup, runs three synchronous `Log.debug` string interpolations,
and (if new) runs NIP-17 three-layer decryption inline. None of this is gated
on the user being in the messages tab.

## Design Decisions

### 1. Lazy Inbox — Subscription Driven by Inbox Visibility

**Decision**: `DmRepository.initialize()` stops auto-starting the subscription.
The inbox screen drives `startListening()` / `stopListening()`.

**Key finding**: `InboxPage` is **unmounted** on tab switch. The app shell uses a
plain `ShellRoute` with `context.go()` — not `StatefulShellRoute` or
`IndexedStack`. Every tab switch destroys the inbox subtree.

**Consequence**: The subscription is truly ephemeral. Start on inbox enter, stop
on leave. When the user returns, do a windowed re-sync. This is the correct
behavior because:

- Cold start does zero DM work.
- Background push notifications do not exist (infrastructure gap, out of scope).
- An unread badge outside the inbox is a separate UI task (out of scope).
- Messages received while outside the inbox arrive on the next inbox visit.

**Lifecycle flow**:

```
User taps Inbox tab
  → InboxPage.build()
    → MultiBlocProvider creates ConversationListBloc
      → ConversationListStarted event
        → dmRepository.startListening()  ← subscription opens

User taps another tab
  → InboxPage unmounted
    → BlocProvider.dispose closes ConversationListBloc
      → ConversationListBloc.close()
        → dmRepository.stopListening()   ← subscription closed
```

**Owner of lifecycle**: `ConversationListBloc`. It already owns the reactive
streams from the repository. Adding `startListening()` in its constructor and
`stopListening()` in `close()` is a natural fit, keeps the lifecycle in the
business logic layer (not the widget), and is testable via `blocTest`.

**Provider change**: `dmRepositoryProvider` no longer calls `initialize()` with
`startListening()` semantics. It still sets auth credentials (pubkey, signer,
messageService) so that send operations and reactive watch queries work
immediately. The provider calls a new `setCredentials()` method that does NOT
start the subscription.

### 2. Count-Based Windowing

**Decision**: Use `limit` and `since` filters to bound relay traffic.

**First inbox open** (no messages in DB):
```
Filter: {kinds: [1059, 4, 5], p: [me], limit: 50}
```
Fetches the 50 most recent events. User can "load older" to paginate backward.

**Subsequent inbox opens** (messages exist in DB):
```
Filter: {kinds: [1059, 4, 5], p: [me], since: newestSyncedAt - 2d}
```
The 2-day overlap absorbs NIP-17's randomized `created_at` timestamps (gift
wraps randomize the outer timestamp up to 2 days in the past for metadata
privacy). This guarantees no missed messages while bounding the replay window.

**"Load older" pagination**:
```
Filter: {kinds: [1059, 4, 5], p: [me], until: oldestSyncedAt, limit: 50}
```
Triggered by the user scrolling to the top of the conversation list or tapping
"Load older messages".

**Sync timestamp source**: `MAX(conversations.last_message_timestamp)` scoped to
`ownerPubkey`. This is:

- Zero-migration: column and index (`idx_conversation_last_message`) already
  exist.
- O(1): SQLite resolves `MAX` over a DESC index with a single seek.
- Correct: every code path that inserts a message also calls
  `upsertConversation(lastMessageTimestamp: rumorEvent.createdAt)`.

New DAO method on `ConversationsDao`:
```dart
Future<int?> getNewestMessageTimestamp({String? ownerPubkey});
```

### 3. Kill the Poller

**Decision**: Remove `_startPolling()` and `_pollTimer` entirely.

The poller was a workaround for relays that don't push real-time events for
`#p`-filtered kind 1059 subscriptions. With the subscription now active only
while the inbox is visible, the WebSocket subscription is the sole event
source. If a relay doesn't push real-time events, the windowed `since` filter
on the next inbox visit catches anything missed.

**Manual QA gate**: Verify DM delivery from a second client while the inbox is
open (no poller fallback). If a relay is found that silently drops real-time
kind 1059, the fix is relay-side, not a client-side poller.

### 4. Debug Log Cleanup

**Decision**: Remove the three per-event `Log.debug` calls at:

- `dm_repository.dart:406–409` — "Received gift wrap event ..."
- `dm_repository.dart:414–416` — "Skipping duplicate gift wrap ..."
- `dm_repository.dart:476–479` — "Skipping NIP-17 duplicate ..."

These were a measurable cost during backlog replay (string interpolation with
64-char hex IDs on the UI isolate, hundreds of times per second). The
`Log.error` calls for failures are kept. The `Log.info` at subscription
start/stop is kept.

### 5. Isolate Decryption (Conditional — Nice-to-Have)

**Decision**: Offload NIP-17 three-layer unwrap via `compute()` for local-key
signers. Remote signers (Keycast RPC, Amber, NIP-46 bunker) stay on the main
isolate because their signing operations are RPC calls that cannot cross
isolate boundaries.

**Go/no-go gate**: A research spike must confirm that the local signer's private
key can be safely extracted and passed to an isolate without violating
security constraints. If the spike shows no safe path, this chunk is cut.

**This chunk is not required for the PR to ship.** Chunks 1–4 alone deliver the
full user-visible performance fix.

## Architecture After Fix

```
App launch
  → isNostrReadyProvider becomes true
    → dmRepositoryProvider calls repository.setCredentials()
      → NO subscription, NO polling, NO merge
      → Reactive watch queries work (Drift streams, cached data)

User taps Inbox tab
  → ConversationListBloc created
    → calls dmRepository.startListening()
      → sync timestamp query: MAX(last_message_timestamp)
      → if null: Filter {limit: 50}
      → if set:  Filter {since: timestamp - 2d}
      → WebSocket subscription opens
    → ConversationListStarted loads cached conversations from DB

User taps another tab
  → ConversationListBloc.close()
    → calls dmRepository.stopListening()
    → subscription closed, no timer, no background work

User taps Inbox tab again
  → Fresh ConversationListBloc
    → startListening() with updated since: timestamp
    → Only new events since last visit are replayed
```

## Non-Goals

- Background push notifications (infrastructure does not exist)
- In-app unread badge outside the inbox tab (separate UI task)
- Data migration / pruning of existing local DM storage
- Replacing NIP-04 legacy support
- Converting `ShellRoute` to `StatefulShellRoute` / `IndexedStack`

## Risks

| Risk | Mitigation |
|---|---|
| Messages missed while outside inbox | Windowed `since` with 2d overlap catches them on next visit |
| Relay doesn't push real-time kind 1059 | Subscription reconnect + windowed re-sync on next inbox enter |
| `stopListening()` fires mid-conversation | Only fires when `ConversationListBloc` is disposed (inbox unmounted), not during a single conversation view push |
| NIP-17 randomized timestamps cause missed events | 2-day overlap in `since` filter handles the protocol's ±2d randomization |
| `_mergeDuplicateConversations()` still runs eagerly | Moved to `startListening()` so it only runs when inbox opens (lazy) |
