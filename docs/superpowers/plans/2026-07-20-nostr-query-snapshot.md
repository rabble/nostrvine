# Nostr Query Snapshot Ownership Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent concurrent mutation of one-shot Nostr query results while they are being persisted asynchronously.

**Architecture:** Establish list ownership at the SDK result, client merge, and DAO persistence boundaries. Each layer takes or returns a shallow list snapshot, while preserving `Event` object identity, event ordering, deduplication, filter limits, and fire-and-forget persistence.

**Tech Stack:** Dart 3.12, Flutter 3.44, `flutter_test`, mocktail, Drift/SQLite.

---

### Task 1: Make completed SDK results stable

**Files:**
- Create: `mobile/packages/nostr_sdk/test/unit/event_mem_box_test.dart`
- Modify: `mobile/packages/nostr_sdk/lib/event_mem_box.dart`

- [ ] **Step 1: Write the failing snapshot test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  group(EventMemBox, () {
    test('all returns a snapshot that is stable after later additions', () {
      const pubkey =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final first = Event(pubkey, EventKind.textNote, [], 'first', createdAt: 1);
      final second = Event(
        pubkey,
        EventKind.textNote,
        [],
        'second',
        createdAt: 2,
      );
      final box = EventMemBox(sortAfterAdd: false)..add(first);

      final completedResult = box.all();
      box.add(second);

      expect(completedResult, equals([first]));
      expect(box.all(), equals([first, second]));
    });
  });
}
```

- [ ] **Step 2: Verify the test is red**

Run:

```bash
cd mobile/packages/nostr_sdk
flutter test test/unit/event_mem_box_test.dart
```

Expected: failure because `completedResult` also contains `second`.

- [ ] **Step 3: Return a detached list**

```dart
List<Event> all() {
  return List<Event>.of(_eventList);
}
```

- [ ] **Step 4: Verify the test is green**

Run:

```bash
cd mobile/packages/nostr_sdk
flutter test test/unit/event_mem_box_test.dart
```

Expected: all tests pass.

### Task 2: Keep client merging pure

**Files:**
- Modify: `mobile/packages/nostr_client/test/src/nostr_client_test.dart`
- Modify: `mobile/packages/nostr_client/lib/src/nostr_client.dart`

- [ ] **Step 1: Write the failing persistence-ownership test**

Add under `Database caching integration` → `queryEvents with cache-first`:

```dart
test('limited merge does not reorder the persistence batch', () async {
  final filters = [
    Filter(kinds: [EventKind.textNote], limit: 1),
  ];
  final older = _createTestEvent(content: 'older', createdAt: 1);
  final newer = _createTestEvent(content: 'newer', createdAt: 2);
  final websocketEvents = [older, newer];
  late List<Event> persistedEvents;

  when(
    () => mockNostrEventsDao.getEventsByFilter(any()),
  ).thenAnswer((_) async => []);
  when(
    () => mockNostr.queryEvents(
      any(),
      id: any(named: 'id'),
      tempRelays: any(named: 'tempRelays'),
      relayTypes: any(named: 'relayTypes'),
      sendAfterAuth: any(named: 'sendAfterAuth'),
    ),
  ).thenAnswer((_) async => websocketEvents);
  when(
    () => mockNostrEventsDao.upsertEventsBatch(any()),
  ).thenAnswer((invocation) async {
    persistedEvents =
        invocation.positionalArguments.first as List<Event>;
  });

  final result = await clientWithCache.queryEvents(filters);

  expect(result, equals([newer]));
  expect(persistedEvents, equals([older, newer]));
  expect(websocketEvents, equals([older, newer]));
});
```

- [ ] **Step 2: Verify the test is red**

Run:

```bash
cd mobile/packages/nostr_client
flutter test test/src/nostr_client_test.dart \
  --plain-name 'limited merge does not reorder the persistence batch'
```

Expected: the persisted/network list is reordered to `[newer, older]`.

- [ ] **Step 3: Copy instead of mutating merge inputs**

Change the empty-cache and empty-network branches of `_mergeEvents()` to
create result lists first, sort those lists only when a limit requires it,
and always return a detached list. Keep the existing map-based deduplication
path unchanged.

```dart
if (cached.isEmpty) {
  final result = List<Event>.of(network);
  if (limit != null && result.length > limit) {
    result.sort((a, b) => b.createdAt - a.createdAt);
    return result.take(limit).toList();
  }
  return result;
}
if (network.isEmpty) {
  final result = List<Event>.of(cached);
  if (limit != null && result.length > limit) {
    result.sort((a, b) => b.createdAt - a.createdAt);
    return result.take(limit).toList();
  }
  return result;
}
```

- [ ] **Step 4: Verify the focused client test is green**

Run the same `flutter test --plain-name` command. Expected: pass.

### Task 3: Make DAO batch ownership synchronous

**Files:**
- Modify: `mobile/packages/db_client/test/src/database/daos/nostr_events_dao_test.dart`
- Modify: `mobile/packages/db_client/lib/src/database/daos/nostr_events_dao.dart`

- [ ] **Step 1: Write the failing caller-mutation test**

Add under `group('upsertEventsBatch')`:

```dart
test('persists a stable snapshot when the caller mutates its list', () async {
  final first = createEvent(content: 'first', createdAt: 1000);
  final second = createEvent(content: 'second', createdAt: 2000);
  final addedLater = createEvent(content: 'added later', createdAt: 3000);
  final events = [first, second];

  final persistence = dao.upsertEventsBatch(events);
  events.add(addedLater);

  await expectLater(persistence, completes);
  expect(await appDbClient.getEvent(first.id), isNotNull);
  expect(await appDbClient.getEvent(second.id), isNotNull);
  expect(await appDbClient.getEvent(addedLater.id), isNull);
});
```

- [ ] **Step 2: Verify the test is red**

Run:

```bash
cd mobile/packages/db_client
flutter test test/src/database/daos/nostr_events_dao_test.dart \
  --plain-name 'persists a stable snapshot when the caller mutates its list'
```

Expected: either `ConcurrentModificationError` or `addedLater` is persisted,
demonstrating that the DAO does not own a stable batch.

- [ ] **Step 3: Snapshot before the first await**

```dart
Future<void> upsertEventsBatch(List<Event> events, {int? expireAt}) async {
  if (events.isEmpty) return;

  final eventsSnapshot = List<Event>.of(events);
  final effectiveExpireAt = expireAt ?? _defaultExpireAt();

  await transaction(() async {
    for (final event in eventsSnapshot) {
      await upsertEvent(event, expireAt: effectiveExpireAt);
    }
  });
}
```

- [ ] **Step 4: Verify the focused DAO test is green**

Run the same `flutter test --plain-name` command. Expected: pass.

### Task 4: Validate, review, and publish

**Files:**
- Review all files changed by Tasks 1–3 and the design/plan documents.

- [ ] **Step 1: Format and run focused package suites**

```bash
cd mobile
dart format \
  packages/nostr_sdk/lib/event_mem_box.dart \
  packages/nostr_sdk/test/unit/event_mem_box_test.dart \
  packages/nostr_client/lib/src/nostr_client.dart \
  packages/nostr_client/test/src/nostr_client_test.dart \
  packages/db_client/lib/src/database/daos/nostr_events_dao.dart \
  packages/db_client/test/src/database/daos/nostr_events_dao_test.dart
cd packages/nostr_sdk && flutter test test/unit/event_mem_box_test.dart
cd ../nostr_client && flutter test test/src/nostr_client_test.dart
cd ../db_client && flutter test test/src/database/daos/nostr_events_dao_test.dart
```

- [ ] **Step 2: Run package and app analysis**

```bash
cd mobile/packages/nostr_sdk && flutter analyze
cd ../nostr_client && flutter analyze
cd ../db_client && flutter analyze
cd ../.. && flutter analyze lib test integration_test
```

- [ ] **Step 3: Review the final diff against #6177**

Confirm no input list is mutated by the changed query flow, all three
regressions can fail when their corresponding fix is reverted, and no
unrelated refactor or generated output is present.

- [ ] **Step 4: Commit the implementation**

```bash
git add \
  mobile/packages/nostr_sdk/lib/event_mem_box.dart \
  mobile/packages/nostr_sdk/test/unit/event_mem_box_test.dart \
  mobile/packages/nostr_client/lib/src/nostr_client.dart \
  mobile/packages/nostr_client/test/src/nostr_client_test.dart \
  mobile/packages/db_client/lib/src/database/daos/nostr_events_dao.dart \
  mobile/packages/db_client/test/src/database/daos/nostr_events_dao_test.dart
git commit -m "fix(nostr): snapshot query results before persistence"
```

- [ ] **Step 5: Rebase, verify, push, and open the PR**

```bash
git fetch origin
git rebase origin/main
git push -u origin fix/6177-nostr-query-snapshot
gh pr create --base main \
  --title "fix(nostr): snapshot query results before persistence"
```

The PR body must include `Fixes #6177`, the confirmed in-place-sort race,
the three ownership boundaries, and exact verification commands.
