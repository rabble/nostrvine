# DM Cold-Start Scaling Fix — Implementation Plan

**Date**: 2026-04-05
**Design**: `2026-04-05-dm-scaling-fix-design.md`
**Issue**: #2766

## Overview

6 chunks, 18 TDD tasks. Chunks 1–4 are the shippable PR (full performance
fix). Chunk 5 is a conditional optimization. Chunk 6 is verification.

**Cut line**: Chunks 1–4 ship the fix. Chunk 5 defers if the signer spike
shows no safe key-extraction path.

---

## Chunk 1: Baseline & Lifecycle Split (6 tasks)

Split `initialize()` into `setCredentials()` (auth only) and `startListening()`
(subscription). Move subscription ownership to `ConversationListBloc`.

### Task 1.1 — Write cold-start regression test

**Type**: Test-first
**File**: `test/repositories/dm_repository_cold_start_test.dart` (new)

Write a test group that:
1. Creates a `DmRepository` with mock `NostrClient`, mock DAOs.
2. Calls the new `setCredentials()` method with valid pubkey + signer.
3. Asserts **zero** calls to:
   - `nostrClient.subscribe()`
   - `nostrClient.queryEvents()`
   - `directMessagesDao.hasGiftWrap()`
   - `directMessagesDao.insertMessage()`
4. Asserts `isInitialized` is `true`.
5. Asserts read operations (`watchConversations`, `watchMessages`) still work.

This test will fail initially (because current `initialize()` calls
`startListening()`). It passes after Task 1.2.

### Task 1.2 — Split `initialize()` into `setCredentials()` + keep `startListening()`

**File**: `mobile/lib/repositories/dm_repository.dart`

Rename current `initialize()` → `setCredentials()`:
- Sets `_userPubkey`, `_signer`, `_messageService`, `_rumorDecryptor`,
  `_nip04Decryptor`.
- Does NOT call `startListening()`.
- Does NOT call `_mergeDuplicateConversations()`.
- Keeps the same idempotency guard (no-op if same user).

`startListening()` remains public but is no longer called from
`setCredentials()`. It gains a new responsibility: calls
`_mergeDuplicateConversations()` on first invocation (gated by a
`_hasMergedConversations` flag so it's idempotent).

Update all internal callers.

### Task 1.3 — Update `dmRepositoryProvider` to call `setCredentials()`

**File**: `mobile/lib/providers/app_providers.dart`

Change the `isNostrReadyProvider` block (lines 1967–1987) to call
`repository.setCredentials(...)` instead of `repository.initialize(...)`.

The `ref.onDispose(repository.stopListening)` stays for cleanup safety.

### Task 1.4 — Update existing tests for the rename

**File**: `test/repositories/dm_repository_test.dart`

All existing tests that call `initialize()` need updating:
- Tests that test subscription behavior: call `setCredentials()` then
  `startListening()` explicitly.
- Tests that only test send/read operations: call `setCredentials()` only.

This is a mechanical rename. All 74 existing tests must pass.

### Task 1.5 — Wire `ConversationListBloc` to drive subscription lifecycle

**Files**:
- `mobile/lib/blocs/dm/conversation_list/conversation_list_bloc.dart`
- `mobile/lib/blocs/dm/conversation_list/conversation_list_event.dart`

Add lifecycle management:
- In the `ConversationListBloc` constructor (or `_onStarted` handler), call
  `_dmRepository.startListening()`.
- Override `close()` to call `_dmRepository.stopListening()` before
  `super.close()`.

The BLoC already holds a `DmRepository` reference. No new dependency.

### Task 1.6 — Write BLoC lifecycle test

**File**: `test/blocs/dm/conversation_list/conversation_list_bloc_test.dart`

Add tests:
1. `startListening()` is called when `ConversationListStarted` is added.
2. `stopListening()` is called when the BLoC is closed.
3. Multiple `ConversationListStarted` events don't duplicate subscriptions
   (idempotency — `startListening()` already guards this).

---

## Chunk 2: Remove Poller (2 tasks)

### Task 2.1 — Write test asserting no timer after `startListening()`

**File**: `test/repositories/dm_repository_cold_start_test.dart`

Add a test:
1. Call `setCredentials()` then `startListening()`.
2. Advance fake time by 30 seconds.
3. Assert `nostrClient.queryEvents()` was NOT called (poller is gone).

### Task 2.2 — Remove `_startPolling()` and `_pollTimer`

**File**: `mobile/lib/repositories/dm_repository.dart`

Delete:
- `_pollTimer` field (line 93)
- `_pollInProgress` field (line 97)
- `_pollInterval` constant (line 192)
- `_startPolling()` method (lines 284–323)
- The `_startPolling()` call in `startListening()` (line 262)
- Timer cancel in `stopListening()` (line 268) and `_resetState()` (line 164)

Update existing tests that verify poll behavior — remove or adapt them.

---

## Chunk 3: Count-Based Windowing + Load Older (5 tasks)

### Task 3.1 — Add `getNewestMessageTimestamp()` to `ConversationsDao`

**File**: `mobile/packages/db_client/lib/src/database/daos/conversations_dao.dart`

```dart
/// Returns the newest `last_message_timestamp` across all conversations
/// for the given owner, or `null` if no conversations exist.
Future<int?> getNewestMessageTimestamp({String? ownerPubkey});
```

Implementation: `selectOnly` with `MAX(lastMessageTimestamp)` and
`_ownedOrLegacy` filter. Uses existing `idx_conversation_last_message` index.

### Task 3.2 — Write DAO test for `getNewestMessageTimestamp()`

**File**: `test/packages/db_client/daos/conversations_dao_test.dart`

Tests:
1. Returns `null` when no conversations exist.
2. Returns the correct max after inserting conversations with different
   timestamps.
3. Scopes correctly by `ownerPubkey`.

### Task 3.3 — Add windowed filter logic to `startListening()`

**File**: `mobile/lib/repositories/dm_repository.dart`

Modify `startListening()`:

```dart
void startListening() async {
  if (_giftWrapSubscription != null || _disposed || !isInitialized) return;

  // Determine sync window
  final newestTimestamp = await _conversationsDao.getNewestMessageTimestamp(
    ownerPubkey: _ownerPubkey,
  );

  final filter = nostr_filter.Filter(
    kinds: [EventKind.giftWrap, EventKind.directMessage, EventKind.eventDeletion],
    p: [_userPubkey],
    // First open: fetch recent batch. Subsequent: window with 2d overlap.
    limit: newestTimestamp == null ? 50 : null,
    since: newestTimestamp != null
        ? newestTimestamp - const Duration(days: 2).inSeconds
        : null,
  );

  // ... rest of subscription setup
}
```

Note: `startListening()` changes from `void` to `Future<void>` (or keeps void
and does the async work internally with `unawaited`). Evaluate which is
cleaner — `ConversationListBloc` can fire-and-forget the call.

### Task 3.4 — Add `loadOlderMessages()` method to `DmRepository`

**File**: `mobile/lib/repositories/dm_repository.dart`

```dart
/// Fetches older messages before the oldest known message.
///
/// Returns the number of new messages fetched, or 0 if none.
Future<int> loadOlderMessages() async {
  final oldestTimestamp = await _conversationsDao.getOldestMessageTimestamp(
    ownerPubkey: _ownerPubkey,
  );

  final filter = nostr_filter.Filter(
    kinds: [EventKind.giftWrap, EventKind.directMessage, EventKind.eventDeletion],
    p: [_userPubkey],
    until: oldestTimestamp,
    limit: 50,
  );

  final events = await _nostrClient.queryEvents([filter], ...);
  var count = 0;
  for (final event in events) {
    await _handleIncomingEvent(event);
    count++;
  }
  return count;
}
```

Also add `getOldestMessageTimestamp()` to `ConversationsDao` (mirror of
`getNewestMessageTimestamp()` using `MIN`).

### Task 3.5 — Write windowing and load-older tests

**File**: `test/repositories/dm_repository_cold_start_test.dart`

Tests:
1. First open (no conversations): `subscribe` filter has `limit: 50` and no
   `since`.
2. Subsequent open (conversations exist with `last_message_timestamp = T`):
   `subscribe` filter has `since: T - 172800` (2 days in seconds) and no
   `limit`.
3. `loadOlderMessages()` uses `until: oldestTimestamp` and `limit: 50`.

---

## Chunk 4: Log Cleanup (1 task)

### Task 4.1 — Remove per-event debug logs

**File**: `mobile/lib/repositories/dm_repository.dart`

Remove these `Log.debug` calls:

1. Lines 406–410: `'Received gift wrap event ${giftWrapEvent.id} from ...'`
2. Lines 414–417: `'Skipping duplicate gift wrap ${giftWrapEvent.id}'`
3. Lines 476–480: `'Skipping NIP-17 duplicate ...'`
4. Lines 559–563: `'Received NIP-04 event ${nip04Event.id} from ...'`
5. Lines 567–571: `'Skipping duplicate NIP-04 event ...'`

Keep:
- `Log.info` at subscription start/stop (operational visibility).
- `Log.error` on failures (debugging).
- `Log.debug` for decrypt failure (rare, useful for debugging).

Update any tests that assert on log output (unlikely but check).

---

## Chunk 5: Isolate Decryption — Conditional (3 tasks)

**Go/no-go gate**: Research spike must confirm local signer private key can be
extracted and passed to `compute()`. If not, skip this chunk entirely.

### Task 5.1 — Research spike: signer key extraction

Investigate:
1. Can `LocalNostrSigner`'s private key be extracted as a `String`?
2. Can `Nostr` + `GiftWrapUtil.getRumorEvent` run in a fresh isolate?
3. Are there any FFI/native plugin dependencies in the NIP-44 decrypt path
   that prevent isolate usage?

Document findings. Go/no-go decision.

### Task 5.2 — Implement `_decryptInIsolate()` helper

**File**: `mobile/lib/repositories/dm_repository.dart`

```dart
Future<Event?> _decryptInIsolate(Event giftWrap) async {
  if (_signer is! LocalNostrSigner) {
    // Remote signer — can't cross isolate boundary
    return _rumorDecryptor(_createNostr(), giftWrap);
  }
  return compute(_isolateDecrypt, (privateKey, giftWrap));
}
```

Top-level function for `compute()`:
```dart
Future<Event?> _isolateDecrypt((String privkey, Event giftWrap) args) async {
  final signer = LocalNostrSigner(args.$1);
  final nostr = Nostr(signer, [], '');
  await nostr.refreshPublicKey();
  return GiftWrapUtil.getRumorEvent(nostr, args.$2);
}
```

### Task 5.3 — Write isolate decryption tests

Test:
1. Local signer: decryption happens off main isolate (verify via mock).
2. Remote signer: decryption stays on main isolate.
3. Both paths produce identical results.

---

## Chunk 6: Verification & Ship (1 task)

### Task 6.1 — Full verification pass

1. `flutter analyze lib test integration_test` — clean.
2. `test/repositories/dm_repository_cold_start_test.dart` — all pass.
3. `test/repositories/dm_repository_test.dart` — all 74+ tests pass.
4. `test/blocs/dm/conversation_list/conversation_list_bloc_test.dart` — lifecycle
   tests pass.
5. Manual QA on dev build:
   - Cold start: logcat shows zero DM pipeline activity.
   - Open inbox: subscription starts, cached conversations load instantly,
     new events stream in.
   - Second-client DM: message appears in inbox while it's open.
   - Tab switch away and back: subscription stops and restarts, no duplicate
     messages.
   - Load older: fetches historical messages on demand.
   - Background/foreground: no crashes, no orphaned timers.
6. On an account with meaningful DM history: time-to-first-frame is no longer
   correlated with message count.

---

## File Change Summary

| File | Change |
|---|---|
| `mobile/lib/repositories/dm_repository.dart` | Split `initialize` → `setCredentials`, windowed filter, remove poller, remove debug logs, add `loadOlderMessages`, move merge to `startListening` |
| `mobile/lib/providers/app_providers.dart` | Call `setCredentials()` instead of `initialize()` |
| `mobile/lib/blocs/dm/conversation_list/conversation_list_bloc.dart` | Drive `startListening()`/`stopListening()` from constructor/close |
| `mobile/packages/db_client/lib/src/database/daos/conversations_dao.dart` | Add `getNewestMessageTimestamp()`, `getOldestMessageTimestamp()` |
| `test/repositories/dm_repository_cold_start_test.dart` | New — cold-start, poller, windowing, load-older tests |
| `test/repositories/dm_repository_test.dart` | Update `initialize()` → `setCredentials()` + explicit `startListening()` |
| `test/blocs/dm/conversation_list/conversation_list_bloc_test.dart` | Add lifecycle tests |
| `test/packages/db_client/daos/conversations_dao_test.dart` | Add timestamp query tests |

## Commit Strategy

One commit per task (18 commits). Each commit is green (tests pass). Squash
into a single PR commit on merge.

Commit message format:
```
fix(dm): <task description> (#2766)
```
