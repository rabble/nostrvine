# DM Scaling Fix Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make DM processing lazy (inbox-gated), bounded (count-based windowing), and non-blocking (isolate decryption for local signers) so cold start and scale do not degrade with lifetime DM count.

**Architecture:** `DmRepository.initialize()` stops auto-starting the gift-wrap subscription. `startListening()` and `stopListening()` are called from the inbox screen's BLoC on mount/dispose. The subscription filter switches between a `limit: 50` first-open path and a `since: newestSyncedAt - 2d` steady-state path, with explicit `loadOlderMessages()` pagination. The 10-second poller is removed. Decryption for local-key signers is offloaded via `compute()` to keep the UI isolate responsive.

**Tech Stack:** Flutter, Riverpod (legacy DmRepository provider), flutter_bloc (InboxPage BLoCs), SQLite via Drift, `nostr_sdk` for NIP-17 decryption, `shared_preferences` for sync-state persistence.

**Design spec:** `mobile/docs/plans/2026-04-05-dm-scaling-fix-design.md` (commit `5c8d9efe7`).

**Key source references:**
- `mobile/lib/repositories/dm_repository.dart:127–151` — `initialize()` currently calls `startListening()`
- `mobile/lib/repositories/dm_repository.dart:206–260` — `startListening()` builds filter + starts poller
- `mobile/lib/repositories/dm_repository.dart:281–320` — `_startPolling()` (to be deleted)
- `mobile/lib/repositories/dm_repository.dart:401–546` — `_handleGiftWrapEvent()` containing the three log lines and the decrypt call
- `mobile/lib/providers/app_providers.dart:1954–1992` — `dmRepositoryProvider` that wires `initialize()` into auth
- `mobile/lib/screens/inbox/inbox_page.dart` — the screen that should drive subscription lifecycle
- `mobile/test/repositories/dm_repository_test.dart` — existing test suite (40+ `startListening` call sites, keep method names stable)

**Scope caveat — isolate decryption:**
NIP-17 three-layer unwrap needs a `NostrSigner`. Local key signers expose raw private key bytes and can cross the isolate boundary; remote signers (Keycast RPC, Amber plugin, NIP-46 bunker) cannot. The plan handles both: local signers use the isolate path, remote signers stay on the main isolate. This is explicit and tested.

**Scope caveat — poller removal:**
The existing poller exists as a workaround for relays that don't push real-time kind 1059 events on a `#p`-filtered subscription. Removing it is a calculated bet: divine relays (`wss://relay.divine.video`) are known to push reliably. The plan includes a manual QA step on staging to verify live push arrival before merge. If push arrival is unreliable, the poller returns as a conditional (only while inbox is visible and only for relays on a known-bad list).

---

## Chunk 1: Baseline and lifecycle split

### Task 1: Set up isolated worktree and baseline

**Files:** none modified

- [ ] **Step 1: Create worktree on a feature branch**

```bash
cd /Users/rabble/code/divine/divine-mobile
git worktree add ../worktrees/dm-scaling fix/dm-scaling-lazy-inbox main
cd ../worktrees/dm-scaling/mobile
```

- [ ] **Step 2: Verify pub get and baseline test suite green**

Run:
```bash
mise exec -- flutter pub get
mise exec -- flutter analyze lib test
mise exec -- flutter test test/repositories/dm_repository_test.dart
```
Expected: analyze clean, all `dm_repository_test.dart` tests pass. If anything is red on main, stop and file an issue — do not start the plan on a red baseline.

- [ ] **Step 3: Install git hooks**

Run: `mise run setup_hooks`
Expected: `.git/hooks/pre-commit` and `.git/hooks/pre-push` exist.

---

### Task 2: Failing test — `initialize()` must not open a subscription

**Files:**
- Modify: `mobile/test/repositories/dm_repository_test.dart`

- [ ] **Step 1: Add failing test**

Find the `group('initialize', …)` block (search for `group('initialize'` in the test file). Add a new test at the end of that group:

```dart
test(
    'initialize does not open a subscription or start a poll timer',
    () async {
  final repository = DmRepository(
    nostrClient: mockClient,
    directMessagesDao: mockDao,
    conversationsDao: mockConvoDao,
  );

  repository.initialize(
    userPubkey: testPubkey,
    signer: mockSigner,
    messageService: mockMessageService,
  );

  // No subscription should have been opened.
  verifyNever(() => mockClient.subscribe(any(), subscriptionId: any(named: 'subscriptionId')));
  // Still isInitialized so send() works.
  expect(repository.isInitialized, isTrue);
});
```

- [ ] **Step 2: Run test, verify it fails**

Run: `mise exec -- flutter test test/repositories/dm_repository_test.dart --name "initialize does not open a subscription"`
Expected: FAIL — `mockClient.subscribe` was called (current behavior).

---

### Task 3: Remove `startListening()` from `initialize()`

**Files:**
- Modify: `mobile/lib/repositories/dm_repository.dart:150`

- [ ] **Step 1: Delete the auto-start call**

In `initialize()` (lines 127–151), delete the final line `startListening();`. Leave a short comment in its place:

```dart
// Subscription is started by the inbox screen via startListening().
// Do NOT start it here — doing so spams gift-wrap processing onto the
// UI isolate at app launch and scales linearly with lifetime DM count.
// See docs/plans/2026-04-05-dm-scaling-fix-design.md.
```

- [ ] **Step 2: Run the test from Task 2, verify it passes**

Run: `mise exec -- flutter test test/repositories/dm_repository_test.dart --name "initialize does not open a subscription"`
Expected: PASS.

- [ ] **Step 3: Run the full DmRepository test file**

Run: `mise exec -- flutter test test/repositories/dm_repository_test.dart`
Expected: Most tests still pass because they call `startListening()` explicitly. Any test that implicitly relied on `initialize()` starting the subscription will fail — fix each one by adding an explicit `repository.startListening();` call after `initialize()` in its setup.

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/repositories/dm_repository.dart mobile/test/repositories/dm_repository_test.dart
git commit -m "$(cat <<'EOF'
refactor(dm): stop starting gift-wrap subscription in initialize()

initialize() now only wires credentials. startListening() becomes the
responsibility of the inbox screen, to be called from its BLoC lifecycle
in a later step. This is the core lazy-DM change: cold start will no
longer process any gift wraps.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Update provider so it does not indirectly start the subscription

**Files:**
- Modify: `mobile/lib/providers/app_providers.dart:1954–1992`

- [ ] **Step 1: Re-read the provider**

Read lines 1954–1992. Confirm that after Task 3, `initialize()` does not open a subscription, so the provider code itself needs no change except a clarifying comment.

- [ ] **Step 2: Add a clarifying comment above `repository.initialize(...)`**

```dart
// initialize() wires credentials only. The gift-wrap subscription
// is started by InboxPage via startListening() and torn down on
// dispose, so cold start does no DM network/decrypt work.
repository.initialize(
  userPubkey: publicKey,
  signer: signer,
  ...
);
```

- [ ] **Step 3: Re-run codegen (Riverpod generator)**

Run: `mise exec -- dart run build_runner build --delete-conflicting-outputs`
Expected: clean run; any generated files updated if needed. Commit generated diffs if any.

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/providers/app_providers.dart mobile/lib/providers/app_providers.g.dart
git commit -m "docs(dm): clarify provider does not trigger DM subscription

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Drive subscription lifecycle from InboxPage

**Files:**
- Modify: `mobile/lib/screens/inbox/inbox_page.dart`
- Modify: `mobile/lib/blocs/dm/conversation_list/conversation_list_bloc.dart` (if needed)
- Test: `mobile/test/screens/inbox/inbox_page_test.dart` (create or extend)

- [ ] **Step 1: Failing widget test — InboxPage starts and stops the subscription**

Create or extend `mobile/test/screens/inbox/inbox_page_test.dart`:

```dart
testWidgets(
  'InboxPage calls startListening on mount and stopListening on dispose',
  (tester) async {
    final mockRepo = _MockDmRepository();
    when(() => mockRepo.startListening()).thenReturn(null);
    when(() => mockRepo.stopListening()).thenAnswer((_) async {});
    when(() => mockRepo.watchConversations(any(named: 'ownerPubkey')))
        .thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dmRepositoryProvider.overrideWith((_) => mockRepo),
          // ... other required overrides
        ],
        child: const MaterialApp(home: InboxPage()),
      ),
    );
    await tester.pump();

    verify(() => mockRepo.startListening()).called(1);

    // Dispose the page.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();

    verify(() => mockRepo.stopListening()).called(1);
  },
);
```

- [ ] **Step 2: Run test — expect failure**

Run: `mise exec -- flutter test test/screens/inbox/inbox_page_test.dart`
Expected: FAIL — `startListening` was not called.

- [ ] **Step 3: Convert InboxPage to a StatefulWidget that owns lifecycle**

Rewrite `mobile/lib/screens/inbox/inbox_page.dart` so it's a `ConsumerStatefulWidget` with `initState` / `dispose`:

```dart
class InboxPage extends ConsumerStatefulWidget {
  const InboxPage({super.key});
  static const routeName = 'inbox';
  static const path = '/inbox';

  @override
  ConsumerState<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends ConsumerState<InboxPage> {
  late final DmRepository _dmRepository;

  @override
  void initState() {
    super.initState();
    _dmRepository = ref.read(dmRepositoryProvider);
    // Lazy DM sync: subscription is opened only while inbox is visible.
    _dmRepository.startListening();
  }

  @override
  void dispose() {
    // Tear down subscription when the inbox closes so the main isolate
    // doesn't keep processing gift wraps in the background.
    unawaited(_dmRepository.stopListening());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dmRepository = _dmRepository;
    // ... rest of the existing build() body unchanged
  }
}
```

Preserve the existing `BlocProvider` wiring verbatim — only the lifecycle hooks are new.

- [ ] **Step 4: Run the test — verify pass**

Run: `mise exec -- flutter test test/screens/inbox/inbox_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Verify full test suite**

Run: `mise exec -- flutter test test/repositories/dm_repository_test.dart test/screens/inbox`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/screens/inbox/inbox_page.dart mobile/test/screens/inbox/inbox_page_test.dart
git commit -m "$(cat <<'EOF'
feat(dm): open/close gift-wrap subscription from InboxPage lifecycle

Converts InboxPage to a ConsumerStatefulWidget that calls
DmRepository.startListening() in initState and stopListening() in
dispose. This is the user-visible half of the lazy-DM change: the app
no longer touches the DM subscription unless the inbox is actually on
screen.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Cold-start regression guard

**Files:**
- Test: `mobile/test/repositories/dm_repository_cold_start_test.dart` (new)

- [ ] **Step 1: Write integration-style test**

```dart
// ABOUTME: Cold-start regression guard — asserts that constructing and
// initializing DmRepository does not touch the relay or the database
// gift-wrap tables. This test is the line in the sand against
// regressing the lazy-DM behavior.

void main() {
  test(
    'cold start: initialize() opens zero subscriptions and reads zero gift wraps',
    () async {
      final mockClient = _MockNostrClient();
      final mockDao = _MockDirectMessagesDao();
      final mockConvoDao = _MockConversationsDao();
      final mockSigner = _MockNostrSigner();

      final repo = DmRepository(
        nostrClient: mockClient,
        directMessagesDao: mockDao,
        conversationsDao: mockConvoDao,
      );

      repo.initialize(
        userPubkey: 'a' * 64,
        signer: mockSigner,
        messageService: _MockNIP17MessageService(),
      );

      // Give any misbehaving async side-effects a chance to run.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verifyNever(() => mockClient.subscribe(any(), subscriptionId: any(named: 'subscriptionId')));
      verifyNever(() => mockClient.queryEvents(any(), subscriptionId: any(named: 'subscriptionId'), useCache: any(named: 'useCache')));
      verifyNever(() => mockDao.hasGiftWrap(any()));
      verifyNever(() => mockDao.insertMessage(
        id: any(named: 'id'),
        conversationId: any(named: 'conversationId'),
        senderPubkey: any(named: 'senderPubkey'),
        content: any(named: 'content'),
        createdAt: any(named: 'createdAt'),
        giftWrapId: any(named: 'giftWrapId'),
        messageKind: any(named: 'messageKind'),
        ownerPubkey: any(named: 'ownerPubkey'),
      ));
    },
  );
}
```

- [ ] **Step 2: Run it, verify pass**

Run: `mise exec -- flutter test test/repositories/dm_repository_cold_start_test.dart`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add mobile/test/repositories/dm_repository_cold_start_test.dart
git commit -m "test(dm): regression guard for zero DM work at cold start

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Chunk 2: Remove the poller

### Task 7: Failing test — no poll timer, no polling queries

**Files:**
- Modify: `mobile/test/repositories/dm_repository_test.dart`

- [ ] **Step 1: Add failing test**

```dart
test(
  'startListening does not create a poll timer or call queryEvents',
  () async {
    // ... standard setup with mockClient that records queryEvents calls
    repository.startListening();

    // Wait longer than the old 10-second poll interval, virtually.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // No queryEvents should fire — live subscription is the only source.
    verifyNever(() => mockClient.queryEvents(
      any(),
      subscriptionId: any(named: 'subscriptionId'),
      useCache: any(named: 'useCache'),
    ));

    await repository.stopListening();
  },
);
```

- [ ] **Step 2: Run, verify fail**

Expected: FAIL — the poll timer is created synchronously by `startListening()` and will eventually fire `queryEvents` (or at minimum, the timer itself will exist).

Because the poll is time-based (10s), the test may *pass* against wall-clock time even with the poller present. Strengthen the test by reaching into the repo for a `@visibleForTesting` getter — see Step 3.

- [ ] **Step 3: Add a `@visibleForTesting` getter on DmRepository**

In `dm_repository.dart`, temporarily expose the timer:

```dart
@visibleForTesting
bool get hasActivePollTimer => _pollTimer != null;
```

And update the test:

```dart
repository.startListening();
expect(repository.hasActivePollTimer, isFalse);
```

- [ ] **Step 4: Re-run, verify fail**

Expected: FAIL — `_pollTimer` is non-null after `startListening()`.

---

### Task 8: Delete the poller

**Files:**
- Modify: `mobile/lib/repositories/dm_repository.dart`

- [ ] **Step 1: Remove poller code**

Delete:
- The `_pollTimer` field (line ~93)
- The `_pollInProgress` field (line ~97)
- The `_pollInterval` constant (lines ~183–189)
- The entire `_startPolling()` method (lines ~281–320)
- The call `_startPolling();` at the end of `startListening()` (line 259)
- References to `_pollTimer`/`_pollInProgress` inside `stopListening()` and `_resetState()`

- [ ] **Step 2: Add a short comment replacing the removed code**

In `startListening()`, replace the deleted `_startPolling()` call with:

```dart
// No poll timer: the live subscription is the sole event source while
// the inbox is open. Poller was removed because it ran forever on the
// UI isolate and re-fetched duplicate events every 10s. If real-time
// push proves unreliable on some relays, re-introduce a *bounded*
// poller only while inbox is visible.
```

- [ ] **Step 3: Run the Task 7 test — verify pass**

Run: `mise exec -- flutter test test/repositories/dm_repository_test.dart --name "does not create a poll timer"`
Expected: PASS.

- [ ] **Step 4: Run full DM test file — fix any polling-dependent tests**

Run: `mise exec -- flutter test test/repositories/dm_repository_test.dart`
Expected: Any test that previously depended on `_startPolling` firing will fail. Update those tests to push events through the subscription stream directly instead of relying on polling.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/repositories/dm_repository.dart mobile/test/repositories/dm_repository_test.dart
git commit -m "$(cat <<'EOF'
refactor(dm): remove 10-second gift-wrap poll timer

The poller ran forever on the UI isolate and re-fetched the last 20
events every 10 seconds, producing constant dedup skips. With the
subscription now bounded to inbox visibility, the live stream is the
only event source. Divine relays push reliably; if a relay misbehaves
the fix belongs behind a feature flag scoped to that relay.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Chunk 3: Count-based windowing and load-older pagination

### Task 9: Add per-pubkey sync-state persistence

**Files:**
- Create: `mobile/lib/repositories/dm_sync_state.dart`
- Test: `mobile/test/repositories/dm_sync_state_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// ABOUTME: Tests for DmSyncState, which persists per-pubkey sync
// boundaries (newest/oldest created_at) so subsequent inbox opens
// can use a `since:` filter instead of fetching the entire backlog.

void main() {
  late SharedPreferences prefs;
  late DmSyncState state;
  const pubkey = 'abc123';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    state = DmSyncState(prefs);
  });

  test('returns null when no state persisted', () {
    expect(state.newestSyncedAt(pubkey), isNull);
    expect(state.oldestSyncedAt(pubkey), isNull);
  });

  test('advances newestSyncedAt monotonically', () async {
    await state.recordSeen(pubkey, createdAt: 100);
    await state.recordSeen(pubkey, createdAt: 200);
    await state.recordSeen(pubkey, createdAt: 150);
    expect(state.newestSyncedAt(pubkey), 200);
    expect(state.oldestSyncedAt(pubkey), 100);
  });

  test('scopes per pubkey', () async {
    await state.recordSeen('alice', createdAt: 100);
    await state.recordSeen('bob', createdAt: 200);
    expect(state.newestSyncedAt('alice'), 100);
    expect(state.newestSyncedAt('bob'), 200);
  });
}
```

- [ ] **Step 2: Run — expect fail (class doesn't exist)**

- [ ] **Step 3: Implement `DmSyncState`**

```dart
// ABOUTME: Persists per-pubkey DM sync boundaries so subsequent inbox
// ABOUTME: opens can fetch only new events via a `since:` filter.
//
// Stores two integers per user pubkey:
//   - newestSyncedAt: highest created_at successfully processed
//   - oldestSyncedAt: lowest created_at successfully processed
//
// Both are unix seconds. Used by DmRepository.startListening() and
// DmRepository.loadOlderMessages() to bound relay queries.

import 'package:shared_preferences/shared_preferences.dart';

class DmSyncState {
  DmSyncState(this._prefs);
  final SharedPreferences _prefs;

  static const _newestPrefix = 'dm.newestSyncedAt.';
  static const _oldestPrefix = 'dm.oldestSyncedAt.';

  int? newestSyncedAt(String pubkey) =>
      _prefs.getInt('$_newestPrefix$pubkey');

  int? oldestSyncedAt(String pubkey) =>
      _prefs.getInt('$_oldestPrefix$pubkey');

  Future<void> recordSeen(String pubkey, {required int createdAt}) async {
    final newest = newestSyncedAt(pubkey);
    if (newest == null || createdAt > newest) {
      await _prefs.setInt('$_newestPrefix$pubkey', createdAt);
    }
    final oldest = oldestSyncedAt(pubkey);
    if (oldest == null || createdAt < oldest) {
      await _prefs.setInt('$_oldestPrefix$pubkey', createdAt);
    }
  }

  Future<void> clear(String pubkey) async {
    await _prefs.remove('$_newestPrefix$pubkey');
    await _prefs.remove('$_oldestPrefix$pubkey');
  }
}
```

- [ ] **Step 4: Run — verify pass**

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/repositories/dm_sync_state.dart mobile/test/repositories/dm_sync_state_test.dart
git commit -m "feat(dm): add DmSyncState for per-pubkey sync boundaries

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: Inject DmSyncState into DmRepository

**Files:**
- Modify: `mobile/lib/repositories/dm_repository.dart`
- Modify: `mobile/lib/providers/app_providers.dart`
- Modify: `mobile/test/repositories/dm_repository_test.dart` (constructor calls)

- [ ] **Step 1: Add constructor parameter**

```dart
DmRepository({
  required NostrClient nostrClient,
  required DirectMessagesDao directMessagesDao,
  required ConversationsDao conversationsDao,
  DmSyncState? syncState, // NEW
  // ... existing params ...
}) : _syncState = syncState,
     // ... rest ...

final DmSyncState? _syncState;
```

Nullable so legacy tests that don't pass it continue to compile; the runtime code checks `_syncState != null` before using it.

- [ ] **Step 2: Update the Riverpod provider**

In `app_providers.dart`, read `sharedPreferencesProvider` and pass a `DmSyncState`:

```dart
final prefs = ref.watch(sharedPreferencesProvider);
final repository = DmRepository(
  nostrClient: nostrService,
  directMessagesDao: db.directMessagesDao,
  conversationsDao: db.conversationsDao,
  syncState: DmSyncState(prefs),
);
```

- [ ] **Step 3: Regenerate Riverpod code**

Run: `mise exec -- dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 4: Run analyze and tests**

Run: `mise exec -- flutter analyze lib test && mise exec -- flutter test test/repositories/dm_repository_test.dart`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(dm): inject DmSyncState into DmRepository

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

### Task 11: First-open vs steady-state filter selection

**Files:**
- Modify: `mobile/lib/repositories/dm_repository.dart`
- Modify: `mobile/test/repositories/dm_repository_test.dart`

- [ ] **Step 1: Failing test — first open uses `limit: 50`, no `since`**

```dart
test(
  'startListening on first ever open uses limit:50 and no since',
  () async {
    when(() => mockSyncState.newestSyncedAt(testPubkey)).thenReturn(null);

    repository.startListening();

    final captured = verify(
      () => mockClient.subscribe(
        captureAny(),
        subscriptionId: any(named: 'subscriptionId'),
      ),
    ).captured.single as List<nostr_filter.Filter>;

    expect(captured.single.limit, 50);
    expect(captured.single.since, isNull);
  },
);
```

- [ ] **Step 2: Failing test — subsequent open uses `since: newest - 2d`**

```dart
test(
  'startListening on subsequent open uses since = newest - 2d',
  () async {
    const newest = 1_700_000_000;
    when(() => mockSyncState.newestSyncedAt(testPubkey)).thenReturn(newest);

    repository.startListening();

    final captured = verify(
      () => mockClient.subscribe(
        captureAny(),
        subscriptionId: any(named: 'subscriptionId'),
      ),
    ).captured.single as List<nostr_filter.Filter>;

    expect(captured.single.since, newest - 2 * 86400);
    expect(captured.single.limit, isNull);
  },
);
```

- [ ] **Step 3: Run both tests — expect fail**

- [ ] **Step 4: Implement filter selection in `startListening()`**

Replace the existing filter construction (lines 209–216) with:

```dart
final newest = _syncState?.newestSyncedAt(_userPubkey);
final isFirstOpen = newest == null;

final filter = nostr_filter.Filter(
  kinds: [
    EventKind.giftWrap,
    EventKind.directMessage,
    EventKind.eventDeletion,
  ],
  p: [_userPubkey],
  // First open: bounded window by count so the backlog can't blow up
  // the UI isolate. Subsequent opens: since-filtered with 2d overlap
  // to absorb NIP-17 randomized timestamps.
  limit: isFirstOpen ? 50 : null,
  since: isFirstOpen ? null : (newest! - 2 * 86400),
);
```

- [ ] **Step 5: Run both tests — verify pass**

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/repositories/dm_repository.dart mobile/test/repositories/dm_repository_test.dart
git commit -m "$(cat <<'EOF'
feat(dm): count-based windowing for gift-wrap subscription

First open fetches limit:50 gift wraps; subsequent opens use
since: newestSyncedAt - 2d (2-day overlap absorbs NIP-17 randomized
timestamps). Makes startup cost bounded regardless of lifetime DM count.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 12: Advance sync boundaries as events are processed

**Files:**
- Modify: `mobile/lib/repositories/dm_repository.dart` (in `_handleGiftWrapEvent` after successful persist)
- Modify: `mobile/test/repositories/dm_repository_test.dart`

- [ ] **Step 1: Failing test**

```dart
test(
  'successful gift-wrap processing advances sync boundaries',
  () async {
    // ... drive a gift-wrap event through the subscription stream ...
    await _pumpGiftWrap(createdAt: 1_700_000_000);

    verify(() => mockSyncState.recordSeen(testPubkey, createdAt: any(named: 'createdAt'))).called(1);
  },
);
```

Note: `recordSeen` uses the rumor's `created_at`, not the gift wrap's randomized one. Use the decrypted rumor's timestamp.

- [ ] **Step 2: Run — expect fail**

- [ ] **Step 3: Implement**

At the end of the successful-persist branch in `_handleGiftWrapEvent` (after the transaction completes at line 531, before the `Log.debug('Persisted DM…')`), add:

```dart
// Track sync boundaries off the rumor timestamp (which is the real
// send time; the gift-wrap created_at is randomized).
await _syncState?.recordSeen(
  _userPubkey,
  createdAt: rumorEvent.createdAt,
);
```

Do the same for the NIP-04 path in `_handleNip04Event` after successful persist. (NIP-04 events have a real `created_at` so the tracking is straightforward.)

- [ ] **Step 4: Run test — verify pass**

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(dm): advance sync boundaries as DMs are persisted

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

### Task 13: `loadOlderMessages()` pagination method

**Files:**
- Modify: `mobile/lib/repositories/dm_repository.dart`
- Modify: `mobile/test/repositories/dm_repository_test.dart`
- Modify: `mobile/lib/blocs/dm/conversation_list/conversation_list_bloc.dart`
- Modify: `mobile/test/blocs/dm/conversation_list/conversation_list_bloc_test.dart`

- [ ] **Step 1: Failing test for `loadOlderMessages()`**

```dart
test(
  'loadOlderMessages queries until=oldestSyncedAt with limit 50',
  () async {
    when(() => mockSyncState.oldestSyncedAt(testPubkey)).thenReturn(1_699_000_000);
    when(() => mockClient.queryEvents(any(), subscriptionId: any(named: 'subscriptionId'), useCache: any(named: 'useCache')))
        .thenAnswer((_) async => []);

    await repository.loadOlderMessages();

    final captured = verify(() => mockClient.queryEvents(
      captureAny(),
      subscriptionId: any(named: 'subscriptionId'),
      useCache: any(named: 'useCache'),
    )).captured.single as List<nostr_filter.Filter>;

    expect(captured.single.until, 1_699_000_000);
    expect(captured.single.limit, 50);
  },
);

test(
  'loadOlderMessages is a no-op if sync state has no oldest yet',
  () async {
    when(() => mockSyncState.oldestSyncedAt(testPubkey)).thenReturn(null);
    await repository.loadOlderMessages();
    verifyNever(() => mockClient.queryEvents(any(), subscriptionId: any(named: 'subscriptionId'), useCache: any(named: 'useCache')));
  },
);
```

- [ ] **Step 2: Run — expect fail**

- [ ] **Step 3: Implement `loadOlderMessages()`**

Add to `DmRepository` (near `startListening`):

```dart
/// Fetches an older page of gift wraps (and NIP-04 messages) from the
/// relay, bounded by [DmSyncState.oldestSyncedAt].
///
/// No-op if the user has never synced (nothing to page backward from —
/// call [startListening] first).
///
/// Events flow through the normal [_handleIncomingEvent] pipeline, so
/// dedup and sync-boundary tracking apply automatically.
Future<void> loadOlderMessages() async {
  if (!isInitialized) return;
  final oldest = _syncState?.oldestSyncedAt(_userPubkey);
  if (oldest == null) return;

  final filter = nostr_filter.Filter(
    kinds: [
      EventKind.giftWrap,
      EventKind.directMessage,
      EventKind.eventDeletion,
    ],
    p: [_userPubkey],
    until: oldest,
    limit: 50,
  );

  final events = await _nostrClient.queryEvents(
    [filter],
    subscriptionId: 'dm_older_${DateTime.now().millisecondsSinceEpoch}',
    useCache: false,
  );

  for (final event in events) {
    await _handleIncomingEvent(event);
  }
}
```

- [ ] **Step 4: Run tests — verify pass**

- [ ] **Step 5: Expose in ConversationListBloc**

Add `ConversationListLoadOlderRequested` event to the bloc and wire it to `_dmRepository.loadOlderMessages()`. Write a matching `blocTest`.

- [ ] **Step 6: Run bloc tests**

Run: `mise exec -- flutter test test/blocs/dm/conversation_list`
Expected: pass.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat(dm): add loadOlderMessages() pagination for DM history

Allows the inbox UI to fetch older gift-wrap pages on demand, bounded
by oldestSyncedAt. ConversationListBloc exposes a new
LoadOlderRequested event that routes to the repository.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Chunk 4: Log cleanup

### Task 14: Remove the three per-event debug logs

**Files:**
- Modify: `mobile/lib/repositories/dm_repository.dart:403–407, 411–414, 467–471`

- [ ] **Step 1: Delete the three `Log.debug` calls**

- Line 403–407: `'Received gift wrap event … from …'` — delete.
- Line 411–414: `'Skipping duplicate gift wrap …'` — delete.
- Line 467–471: `'Skipping NIP-17 duplicate (NIP-04 copy already stored) …'` — delete.

No replacement needed. The successful-persist log at line 533 stays; error logs stay.

- [ ] **Step 2: Run full DM test file**

Run: `mise exec -- flutter test test/repositories/dm_repository_test.dart`
Expected: all pass.

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/repositories/dm_repository.dart
git commit -m "$(cat <<'EOF'
refactor(dm): drop per-event debug logs in gift-wrap handler

Three Log.debug calls (received, skip-duplicate, skip-nip17-dup) fired
for every incoming gift wrap. On a backlog replay that was hundreds of
synchronous string-interpolation + log calls on the UI isolate before
any useful work. Errors and successful persistence remain logged.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Chunk 5: Isolate decryption (local signers only)

### Task 15: Research spike — identify local vs remote signer type

**Files:** none modified (investigation only)

- [ ] **Step 1: Find the concrete signer implementations**

```bash
cd /Users/rabble/code/divine/divine-mobile/mobile
```

Use Grep to find classes that `implements NostrSigner` or `extends NostrSigner`. Record:
- Which class represents a local private-key signer (will expose raw key bytes).
- Which classes represent remote signers (Keycast RPC, Amber, NIP-46 bunker) that cannot cross an isolate.
- Whether the local signer has a public getter for raw private key bytes.

- [ ] **Step 2: Document findings in the plan**

Add a short note to the top of `dm_decryption_worker.dart` (next task) recording the exact class name of the local signer and the API used to extract its key. If no public getter exists, decide between (a) adding one, or (b) computing the NIP-44 shared secret on the main isolate and passing that to the isolate instead of the raw key.

- [ ] **Step 3: Go/no-go decision**

If no safe extraction path exists for local keys, **skip Chunk 5 entirely**. The lifecycle + poller + windowing changes alone solve the scaling problem. Write a short note in the plan marking Chunk 5 as deferred and move straight to Chunk 6. Do NOT half-implement the isolate path.

---

### Task 16: Isolate worker entry point

**Files:**
- Create: `mobile/lib/repositories/dm_decryption_worker.dart`
- Test: `mobile/test/repositories/dm_decryption_worker_test.dart`

Only proceed if Task 15 returned a viable key-extraction path.

- [ ] **Step 1: Failing test**

```dart
// ABOUTME: Tests for the DM decryption isolate worker. Runs under the
// ABOUTME: current isolate in tests (compute() uses Isolate.run in
// ABOUTME: release; tests can invoke the top-level function directly).

void main() {
  test('decryptGiftWrapBatch returns empty for empty input', () async {
    final result = await decryptGiftWrapBatch(
      DecryptBatchRequest(events: const [], privateKeyHex: 'a' * 64),
    );
    expect(result, isEmpty);
  });

  test('decryptGiftWrapBatch preserves input order', () async {
    // ... seeded test vectors ...
  });

  test('decryptGiftWrapBatch emits error entry for malformed event', () async {
    // ... pass one good and one malformed event ...
    expect(result.length, 2);
    expect(result[0].error, isNull);
    expect(result[1].error, isNotNull);
    expect(result[1].rumor, isNull);
  });
}
```

- [ ] **Step 2: Implement the worker**

```dart
// ABOUTME: Top-level function for off-main-isolate NIP-17 gift-wrap
// ABOUTME: decryption. Accepts a batch of raw events and a private key,
// ABOUTME: returns decrypted rumors in input order. Only usable with
// ABOUTME: local key signers that expose raw key bytes.

// ... implementation using nostr_sdk's standalone decrypt helpers ...

class DecryptBatchRequest {
  const DecryptBatchRequest({required this.events, required this.privateKeyHex});
  final List<Map<String, dynamic>> events;
  final String privateKeyHex;
}

class DecryptedRumorResult {
  const DecryptedRumorResult({this.rumor, this.error});
  final Map<String, dynamic>? rumor;
  final String? error;
}

Future<List<DecryptedRumorResult>> decryptGiftWrapBatch(
  DecryptBatchRequest request,
) async {
  // implementation
}
```

- [ ] **Step 3: Run tests — verify pass**

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/repositories/dm_decryption_worker.dart mobile/test/repositories/dm_decryption_worker_test.dart
git commit -m "feat(dm): add dm_decryption_worker for compute()-based unwrap

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

### Task 17: Wire batching + `compute()` into DmRepository

**Files:**
- Modify: `mobile/lib/repositories/dm_repository.dart`
- Modify: `mobile/test/repositories/dm_repository_test.dart`

- [ ] **Step 1: Failing test — when signer is local, decryption goes through compute()**

Use an injectable `typedef GiftWrapBatchDecryptor` (mirror the existing `RumorDecryptor` pattern) so tests can assert batching without actually spawning isolates.

- [ ] **Step 2: Implement batching**

Buffer incoming gift-wrap events in a `List<Event> _decryptQueue` with a 250ms debounce timer. Flush = pass the buffer to the batch decryptor (which calls `compute(decryptGiftWrapBatch, …)` in production) and process results in the existing pipeline.

For non-local signers, fall back to the existing per-event `_rumorDecryptor` path on the main isolate.

- [ ] **Step 3: Run tests — verify pass**

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat(dm): offload gift-wrap decryption to compute() for local signers

Batches incoming gift wraps with a 250ms debounce and decrypts each
batch in a background isolate when the signer can expose raw key
bytes. Remote signers (Keycast/Amber/NIP-46) continue to decrypt on
the main isolate because they can't cross the isolate boundary.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Chunk 6: Verification and ship

### Task 18: Full suite, analyze, codegen

- [ ] **Step 1: Full analyze**

Run: `mise exec -- flutter analyze lib test integration_test`
Expected: clean.

- [ ] **Step 2: Full test suite**

Run: `mise exec -- flutter test`
Expected: all pass.

- [ ] **Step 3: Codegen sanity check**

Run: `mise exec -- dart run build_runner build --delete-conflicting-outputs`
Expected: no diff beyond what's already committed.

- [ ] **Step 4: Manual QA on a dev build**

- Launch app on an account with existing DM history. Confirm log output is silent for the gift-wrap pipeline.
- Navigate away from inbox, scroll feed for 30 seconds. Confirm no DM-related log lines.
- Open inbox. Confirm subscription opens, conversation list populates, live messages arrive.
- Send yourself a DM from a second client. Confirm it arrives in real-time (validates that push works without the poller).
- Tap "load older" (or scroll to top). Confirm older messages populate.
- Background the app, foreground it. Confirm subscription tears down and re-opens cleanly.

- [ ] **Step 5: If manual QA passes, push branch and open PR**

Run:
```bash
git push -u origin fix/dm-scaling-lazy-inbox
gh pr create --title "fix(dm): lazy inbox subscription, count-based sync, no poller" \
  --body "$(cat <<'EOF'
## Summary
- Stops opening the gift-wrap subscription at app start; InboxPage drives it now.
- Adds count-based windowing (first open: limit 50; subsequent: since = newest - 2d).
- Removes the 10-second poll timer.
- Drops three per-event debug log lines that fired on every gift-wrap.
- Adds `loadOlderMessages()` pagination.
- (If Chunk 5 landed) offloads decryption to compute() for local signers.

Design: `mobile/docs/plans/2026-04-05-dm-scaling-fix-design.md`
Plan:   `mobile/docs/plans/2026-04-05-dm-scaling-fix-implementation.md`

## Test plan
- [ ] `flutter analyze lib test integration_test`
- [ ] `flutter test test/repositories/dm_repository_test.dart`
- [ ] `flutter test test/repositories/dm_repository_cold_start_test.dart`
- [ ] `flutter test test/repositories/dm_sync_state_test.dart`
- [ ] `flutter test test/screens/inbox`
- [ ] Manual QA: cold start is silent; inbox opens and receives live DMs; load-older works; push delivery verified without poller.
EOF
)"
```

---

## Summary of chunks

| Chunk | What lands | Risk |
|-------|-----------|------|
| 1. Baseline & lifecycle split | DmRepository stops auto-starting; InboxPage drives it | Low — tested with mocks |
| 2. Remove poller | 10s timer gone; live subscription is sole source | Medium — depends on relay push behavior; QA gate |
| 3. Count-based windowing | Bounded first-open; `since:` on return; load-older API | Low — filter change, backed by dedup |
| 4. Log cleanup | Three debug lines removed | Trivial |
| 5. Isolate decryption (conditional) | Local-signer decrypts move off UI isolate | Medium — conditional on Task 15 spike |
| 6. Verification & ship | Analyze, tests, manual QA, PR | — |

The plan is **mergable after Chunk 4** even if Chunk 5 is deferred. Chunks 1–4 alone deliver the user-visible performance fix; Chunk 5 is an optimization on top.
