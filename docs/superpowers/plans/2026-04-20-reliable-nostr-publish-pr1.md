# Reliable Nostr Publish — PR 1: Foundation, Reference Migration, UX Mapper

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every Nostr publish in divine-mobile a path to real relay confirmation (NIP-20 OK frames), bounded retry on transient failure, and a consistent mapping from publish outcome to user-facing state. PR 1 lands the primitives, the retry policy, the UX mapper, and migrates the NIP-09 content-deletion flow as the reference implementation. Later PRs (2–8) migrate service domains onto this foundation.

**Architecture:** The reliability stack has four layers, each in an existing package so no new top-level packages are introduced.

1. **`nostr_sdk/RelayPool`** receives NIP-20 `OK` frames and routes them to per-publish completers via a new `sendAwaitOk` method. Existing AUTH handling stays unchanged.
2. **`nostr_sdk/Nostr.sendEventAwaitOk`** signs and broadcasts an event, then returns a `PublishOutcome` built from the per-relay OK results.
3. **`nostr_client/NostrClient.publishEventAwaitOk`** wraps the SDK call, reuses the existing optimistic-cache and relay-health behavior, and exposes `PublishOutcome` to callers. A sibling `publishEventWithRetry` applies a `RetryPolicy` (exponential backoff, retry only `noResponseFrom` + transient rejections).
4. **`nostr_client/PublishResultMapper`** turns a `PublishOutcome` into a `PublishUserFeedback` value (severity + i18n key + retryable flag) so UI layers can consume it uniformly.

The NIP-09 deletion service migrates first and `share_video_menu.dart`'s delete path drives the UX mapper — this is the reference flow future PRs copy.

**Tech Stack:** Dart / Flutter, `nostr_sdk` (internal package), `nostr_client` (internal package), `mocktail` for test doubles, `flutter_test` for widget tests, `very_good_analysis` lints.

---

## File Structure

### Created files

- `mobile/packages/nostr_sdk/lib/relay/publish_outcome.dart` — `PublishOutcome` value type (owned here so both `Nostr` and `NostrClient` can see it without a cyclic import).
- `mobile/packages/nostr_sdk/lib/relay/_pending_publish.dart` — internal `_PendingPublish` record tracking per-event completers keyed by event id, with per-relay `Map<String, PublishAck>` state.
- `mobile/packages/nostr_sdk/test/relay/relay_pool_publish_ok_test.dart` — unit tests for the new `RelayPool.sendAwaitOk` path.
- `mobile/packages/nostr_sdk/test/publish_outcome_test.dart` — unit tests for the `PublishOutcome` type.
- `mobile/packages/nostr_client/lib/src/publish_result_mapper.dart` — outcome → user feedback mapping.
- `mobile/packages/nostr_client/lib/src/retry_policy.dart` — `RetryPolicy` config + `ReliablePublisher` helper class.
- `mobile/packages/nostr_client/test/src/publish_event_await_ok_test.dart` — unit tests for `NostrClient.publishEventAwaitOk`.
- `mobile/packages/nostr_client/test/src/publish_event_with_retry_test.dart` — unit tests for `NostrClient.publishEventWithRetry`.
- `mobile/packages/nostr_client/test/src/publish_result_mapper_test.dart` — unit tests for the mapper.
- `mobile/test/unit/services/content_deletion_service_reliability_test.dart` — tests that the deletion service surfaces per-outcome results.

### Modified files

- `mobile/packages/nostr_sdk/lib/relay/relay_pool.dart` — extend `OK` handler (currently AUTH-only at `:369`) to resolve pending publishes; add `Future<PublishOutcome> sendAwaitOk(...)` method (alongside existing `send`).
- `mobile/packages/nostr_sdk/lib/nostr.dart` — add `Future<PublishOutcome> sendEventAwaitOk(Event, {timeout, targetRelays, tempRelays})` mirroring `sendEvent` at `:179` but returning an outcome.
- `mobile/packages/nostr_sdk/lib/nostr_sdk.dart` — export `PublishOutcome` from the package's public API.
- `mobile/packages/nostr_client/lib/src/nostr_client.dart` — add `Future<PublishOutcome> publishEventAwaitOk(...)` and `Future<PublishOutcome> publishEventWithRetry(...)` alongside the existing `publishEvent` at `:241`. Extend `NostrClientStatisticsObserver` with `onPublishOutcome(PublishOutcome)`.
- `mobile/packages/nostr_client/lib/nostr_client.dart` — export `PublishOutcome`, `RetryPolicy`, `PublishUserFeedback`, `PublishResultMapper`.
- `mobile/lib/services/content_deletion_service.dart` — replace the `publishEvent` call at `:150` with `publishEventWithRetry`; store the outcome on `DeleteResult` so callers can distinguish accepted-by-all / accepted-partial / rejected / timed-out.
- `mobile/lib/widgets/share_video_menu.dart` — consume the new `DeleteResult.outcome` to render retry-able failure snackbars via `PublishResultMapper`. (This is the UX-mapper reference wiring; later PRs copy this pattern.)

### Why this split

- `PublishOutcome` lives in `nostr_sdk` because `RelayPool` is the lowest layer that knows per-relay acknowledgements, and pushing the type down prevents cyclic imports when `NostrClient` and `Nostr` both need to see it.
- `RetryPolicy` + `ReliablePublisher` live in `nostr_client` because retry is a policy over the primitive, and `nostr_sdk` intentionally stays dumb about scheduling.
- `PublishResultMapper` lives in `nostr_client` rather than a UI package because outcome → severity is a pure function with no widget dependencies, and keeping it next to the primitive makes it one-stop for service-domain migrations.

---

## Chunk 1: `PublishOutcome` value type

### Task 1.1: Define `PublishOutcome` and `PublishAck` types

**Files:**
- Create: `mobile/packages/nostr_sdk/lib/relay/publish_outcome.dart`
- Test: `mobile/packages/nostr_sdk/test/publish_outcome_test.dart`

**Background:** This is the shared vocabulary for "what happened when we tried to publish". A `PublishOutcome` summarizes the responses from every target relay. Callers need to distinguish:
- At least one relay sent `["OK", id, true, ...]` → the event is durable.
- A relay sent `["OK", id, false, "<reason>"]` → it was rejected; the reason prefix tells us if it's transient or permanent per NIP-01.
- Timeout elapsed → no response frame arrived (neither accept nor reject).

- [ ] **Step 1: Write the failing tests**

Create `mobile/packages/nostr_sdk/test/publish_outcome_test.dart`:

```dart
// ABOUTME: Unit tests for PublishOutcome value type.

import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:test/test.dart';

void main() {
  group(PublishOutcome, () {
    test('acceptedByAll returns true when every relay accepted', () {
      final outcome = PublishOutcome(
        eventId: 'event-id-1',
        acceptedBy: const {'wss://a', 'wss://b'},
        rejectedBy: const {},
        noResponseFrom: const {},
      );

      expect(outcome.acceptedByAll, isTrue);
      expect(outcome.acceptedByAny, isTrue);
      expect(outcome.failed, isFalse);
    });

    test('acceptedByAny true when at least one accepts, even with rejects', () {
      final outcome = PublishOutcome(
        eventId: 'event-id-2',
        acceptedBy: const {'wss://a'},
        rejectedBy: const {'wss://b': 'blocked: spam'},
        noResponseFrom: const {},
      );

      expect(outcome.acceptedByAny, isTrue);
      expect(outcome.acceptedByAll, isFalse);
      expect(outcome.failed, isFalse);
    });

    test('failed true when no relay accepted', () {
      final outcome = PublishOutcome(
        eventId: 'event-id-3',
        acceptedBy: const {},
        rejectedBy: const {'wss://a': 'invalid: sig'},
        noResponseFrom: const {'wss://b'},
      );

      expect(outcome.failed, isTrue);
      expect(outcome.acceptedByAny, isFalse);
    });

    test('transientRelays = noResponseFrom plus rejectedBy with retryable '
        'reason prefixes', () {
      final outcome = PublishOutcome(
        eventId: 'event-id-4',
        acceptedBy: const {},
        rejectedBy: const {
          'wss://permanent': 'blocked: user',
          'wss://transient': 'error: temporarily unavailable',
          'wss://auth': 'auth-required: challenge',
          'wss://rate': 'rate-limited: too fast',
        },
        noResponseFrom: const {'wss://silent'},
      );

      expect(outcome.transientRelays, {'wss://transient', 'wss://silent'});
    });

    test('permanently rejected prefixes do NOT appear in transientRelays', () {
      // NIP-01 machine-readable prefixes treated as permanent:
      //   blocked:, invalid:, pow:, restricted:, auth-required:, rate-limited:
      final outcome = PublishOutcome(
        eventId: 'event-id-5',
        acceptedBy: const {},
        rejectedBy: const {
          'wss://blocked': 'blocked: banned',
          'wss://invalid': 'invalid: schema',
          'wss://pow': 'pow: insufficient difficulty',
          'wss://restricted': 'restricted: paid relay',
        },
        noResponseFrom: const {},
      );

      expect(outcome.transientRelays, isEmpty);
    });

    test('preserves full event id (no truncation) in toString', () {
      const fullId = 'a' * 64; // Nostr event id is 64 hex chars
      final outcome = PublishOutcome(
        eventId: fullId,
        acceptedBy: const {},
        rejectedBy: const {},
        noResponseFrom: const {},
      );

      expect(outcome.toString(), contains(fullId));
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd mobile/packages/nostr_sdk && dart test test/publish_outcome_test.dart`
Expected: FAIL — file `lib/relay/publish_outcome.dart` does not exist.

- [ ] **Step 3: Implement `PublishOutcome`**

Create `mobile/packages/nostr_sdk/lib/relay/publish_outcome.dart`:

```dart
// ABOUTME: PublishOutcome summarizes per-relay NIP-20 OK responses for a single publish.
// ABOUTME: Returned by RelayPool.sendAwaitOk, Nostr.sendEventAwaitOk, and NostrClient.publishEventAwaitOk.

import 'package:meta/meta.dart';

/// Permanent rejection prefixes per NIP-01. Relays emit these in the fourth
/// element of an `["OK", id, false, reason]` frame to hint at whether a retry
/// could succeed. We treat these as permanent — retry would be wasted work.
const Set<String> _permanentRejectionPrefixes = {
  'blocked:',
  'invalid:',
  'pow:',
  'restricted:',
  'auth-required:',
  'rate-limited:',
};

/// Result of publishing a single Nostr event to one or more relays.
///
/// A publish can have three outcomes per relay:
/// - Accepted: relay sent `["OK", id, true, _]`
/// - Rejected: relay sent `["OK", id, false, reason]`
/// - No response: timeout elapsed without any OK frame
///
/// Callers decide user-facing behavior based on the combined result. See
/// [acceptedByAll], [acceptedByAny], [failed], and [transientRelays].
@immutable
class PublishOutcome {
  const PublishOutcome({
    required this.eventId,
    required this.acceptedBy,
    required this.rejectedBy,
    required this.noResponseFrom,
  });

  /// Full 64-hex-char event id — never truncated.
  final String eventId;

  /// Relay URLs that responded with `["OK", id, true, _]`.
  final Set<String> acceptedBy;

  /// Relay URLs that responded with `["OK", id, false, reason]`, mapped to
  /// the reason string (may be empty).
  final Map<String, String> rejectedBy;

  /// Relay URLs that were targeted but did not respond within the timeout.
  final Set<String> noResponseFrom;

  /// True when every targeted relay accepted.
  bool get acceptedByAll =>
      acceptedBy.isNotEmpty && rejectedBy.isEmpty && noResponseFrom.isEmpty;

  /// True when at least one relay accepted.
  bool get acceptedByAny => acceptedBy.isNotEmpty;

  /// True when no relay accepted.
  bool get failed => acceptedBy.isEmpty;

  /// Relays that *could* succeed on retry — no-response plus rejections whose
  /// reason does not start with a permanent NIP-01 prefix.
  Set<String> get transientRelays {
    final transient = <String>{...noResponseFrom};
    rejectedBy.forEach((relay, reason) {
      if (!_isPermanent(reason)) transient.add(relay);
    });
    return transient;
  }

  static bool _isPermanent(String reason) {
    for (final prefix in _permanentRejectionPrefixes) {
      if (reason.startsWith(prefix)) return true;
    }
    return false;
  }

  @override
  String toString() =>
      'PublishOutcome(eventId: $eventId, '
      'acceptedBy: $acceptedBy, '
      'rejectedBy: $rejectedBy, '
      'noResponseFrom: $noResponseFrom)';
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd mobile/packages/nostr_sdk && dart test test/publish_outcome_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Export from the package barrel**

Modify `mobile/packages/nostr_sdk/lib/nostr_sdk.dart` — add:

```dart
export 'relay/publish_outcome.dart';
```

- [ ] **Step 6: Commit**

```bash
git add mobile/packages/nostr_sdk/lib/relay/publish_outcome.dart \
        mobile/packages/nostr_sdk/test/publish_outcome_test.dart \
        mobile/packages/nostr_sdk/lib/nostr_sdk.dart
git commit -m "feat(nostr_sdk): add PublishOutcome value type for relay acks"
```

---

## Chunk 2: `RelayPool.sendAwaitOk`

### Task 2.1: Track pending publishes and resolve on OK frames

**Files:**
- Modify: `mobile/packages/nostr_sdk/lib/relay/relay_pool.dart`
- Create: `mobile/packages/nostr_sdk/test/relay/relay_pool_publish_ok_test.dart`

**Background:** `RelayPool` already parses `OK` frames (line 369) but only uses them to resolve AUTH. We extend the handler to also resolve pending publish completers, and add a new `sendAwaitOk` method that returns a `PublishOutcome` built from per-relay results.

Key design decisions:
- Keyed by event id. NIP-20 guarantees `["OK", event_id, ...]` so event id is a unique key per in-flight publish.
- Only track publishes with event id (i.e. signed EVENT frames). AUTH events piggyback on the same frame type but use the separate `_pendingAuthEvents` map already in place.
- Pending publishes expire via `Timer` on the configured timeout; on expiry, any relay that has not yet responded is counted in `noResponseFrom`.
- The completer resolves as soon as **every targeted relay** has either accepted, rejected, or timed out. We do NOT short-circuit on the first OK — callers need the full per-relay picture for partial-success UX and retry.

- [ ] **Step 1: Write the failing tests**

Create `mobile/packages/nostr_sdk/test/relay/relay_pool_publish_ok_test.dart`:

```dart
// ABOUTME: Tests for RelayPool.sendAwaitOk — resolves when all targeted relays
// ABOUTME: have responded OK, sent a reject, or the timeout elapses.

import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/relay/relay.dart';
import 'package:nostr_sdk/relay/relay_pool.dart';
import 'package:nostr_sdk/relay/relay_status.dart';
import 'package:test/test.dart';

class _MockNostr extends Mock implements Nostr {}

class _FakeRelay extends Fake implements Relay {
  _FakeRelay(this.url) : relayStatus = RelayStatus(url);

  @override
  final String url;

  @override
  final RelayStatus relayStatus;

  bool sendCalled = false;

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool forceSend = false,
  }) async {
    sendCalled = true;
    relayStatus.writeAccess = true;
    return true;
  }
}

void main() {
  group('RelayPool.sendAwaitOk', () {
    late _MockNostr nostr;
    late RelayPool pool;
    late _FakeRelay relayA;
    late _FakeRelay relayB;

    setUp(() {
      nostr = _MockNostr();
      relayA = _FakeRelay('wss://a')..relayStatus.writeAccess = true;
      relayB = _FakeRelay('wss://b')..relayStatus.writeAccess = true;
      pool = RelayPool(nostr, const [], (addr) => _FakeRelay(addr))
        ..addRelay(relayA)
        ..addRelay(relayB);
    });

    Event _signedEvent(String id) {
      final event = Event('pubkey', EventKind.textNote, const [], 'hi')
        ..id = id
        ..sig = 'sig';
      return event;
    }

    test('resolves accepted when all relays send OK=true', () async {
      final event = _signedEvent('a' * 64);

      final future = pool.sendAwaitOk(
        event,
        timeout: const Duration(seconds: 2),
      );

      // Simulate OK frames from both relays.
      pool.handleMessageForTesting(relayA, ['OK', event.id, true, '']);
      pool.handleMessageForTesting(relayB, ['OK', event.id, true, 'accepted']);

      final outcome = await future;
      expect(outcome.eventId, event.id);
      expect(outcome.acceptedBy, {'wss://a', 'wss://b'});
      expect(outcome.rejectedBy, isEmpty);
      expect(outcome.noResponseFrom, isEmpty);
      expect(outcome.acceptedByAll, isTrue);
    });

    test('records per-relay rejection reason', () async {
      final event = _signedEvent('b' * 64);

      final future = pool.sendAwaitOk(
        event,
        timeout: const Duration(seconds: 2),
      );

      pool.handleMessageForTesting(relayA, ['OK', event.id, true, '']);
      pool.handleMessageForTesting(
        relayB,
        ['OK', event.id, false, 'blocked: user'],
      );

      final outcome = await future;
      expect(outcome.acceptedBy, {'wss://a'});
      expect(outcome.rejectedBy, {'wss://b': 'blocked: user'});
      expect(outcome.noResponseFrom, isEmpty);
    });

    test('relays with no response land in noResponseFrom after timeout',
        () async {
      final event = _signedEvent('c' * 64);

      final future = pool.sendAwaitOk(
        event,
        timeout: const Duration(milliseconds: 50),
      );

      pool.handleMessageForTesting(relayA, ['OK', event.id, true, '']);
      // relayB silent.

      final outcome = await future;
      expect(outcome.acceptedBy, {'wss://a'});
      expect(outcome.rejectedBy, isEmpty);
      expect(outcome.noResponseFrom, {'wss://b'});
    });

    test('unrelated OK frames do not resolve the publish', () async {
      final event = _signedEvent('d' * 64);

      final future = pool.sendAwaitOk(
        event,
        timeout: const Duration(milliseconds: 50),
      );

      // OK for a different event id — must be ignored.
      pool.handleMessageForTesting(relayA, ['OK', 'z' * 64, true, '']);
      pool.handleMessageForTesting(relayB, ['OK', 'z' * 64, true, '']);

      final outcome = await future;
      expect(outcome.acceptedBy, isEmpty);
      expect(outcome.noResponseFrom, {'wss://a', 'wss://b'});
    });

    test('pending publish is cleaned up after resolution', () async {
      final event = _signedEvent('e' * 64);

      final future = pool.sendAwaitOk(
        event,
        timeout: const Duration(milliseconds: 50),
      );

      pool.handleMessageForTesting(relayA, ['OK', event.id, true, '']);
      pool.handleMessageForTesting(relayB, ['OK', event.id, true, '']);

      await future;
      expect(pool.pendingPublishCountForTesting, 0);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd mobile/packages/nostr_sdk && dart test test/relay/relay_pool_publish_ok_test.dart`
Expected: FAIL — `sendAwaitOk` / `handleMessageForTesting` / `pendingPublishCountForTesting` / `addRelay` testing surface do not exist.

- [ ] **Step 3: Add the internal pending-publish record**

Add to the top of `mobile/packages/nostr_sdk/lib/relay/relay_pool.dart`, just below existing imports:

```dart
import 'publish_outcome.dart';
```

Add these private types at the end of the file (outside the `RelayPool` class):

```dart
class _PendingPublish {
  _PendingPublish({
    required this.eventId,
    required this.targetRelays,
    required this.timeout,
  }) : completer = Completer<PublishOutcome>() {
    timer = Timer(timeout, _onTimeout);
  }

  final String eventId;
  final Set<String> targetRelays;
  final Duration timeout;
  final Completer<PublishOutcome> completer;
  late final Timer timer;

  final Set<String> _acceptedBy = {};
  final Map<String, String> _rejectedBy = {};

  void recordOk(String relayUrl, bool accepted, String reason) {
    if (!targetRelays.contains(relayUrl)) return;
    if (_acceptedBy.contains(relayUrl) || _rejectedBy.containsKey(relayUrl)) {
      return; // ignore duplicate
    }
    if (accepted) {
      _acceptedBy.add(relayUrl);
    } else {
      _rejectedBy[relayUrl] = reason;
    }
    if (_isComplete) _finish();
  }

  bool get _isComplete =>
      (_acceptedBy.length + _rejectedBy.length) >= targetRelays.length;

  void _finish() {
    if (completer.isCompleted) return;
    timer.cancel();
    final noResponse = targetRelays
        .difference(_acceptedBy)
        .difference(_rejectedBy.keys.toSet());
    completer.complete(
      PublishOutcome(
        eventId: eventId,
        acceptedBy: Set.unmodifiable(_acceptedBy),
        rejectedBy: Map.unmodifiable(_rejectedBy),
        noResponseFrom: Set.unmodifiable(noResponse),
      ),
    );
  }

  void _onTimeout() {
    _finish();
  }

  void cancelTimer() => timer.cancel();
}
```

Add to `RelayPool` as instance state:

```dart
final Map<String, _PendingPublish> _pendingPublishes = {};
```

- [ ] **Step 4: Extend the OK handler**

In `mobile/packages/nostr_sdk/lib/relay/relay_pool.dart`, locate the OK-frame branch (currently at `:369`):

```dart
} else if (messageType == "OK") {
  log('📡 OK response from ${relay.url}: $json');

  if (json.length >= 3) {
    final eventId = json[1] as String;
    final success = json[2] as bool;
    final message = json.length > 3 ? json[3] as String : '';

    if (_pendingAuthEvents.containsKey(eventId)) {
      // … existing AUTH logic unchanged …
    }
  }
}
```

Modify the inner body so that, after the AUTH branch, we also resolve any pending publish:

```dart
} else if (messageType == "OK") {
  log('📡 OK response from ${relay.url}: $json');

  if (json.length >= 3) {
    final eventId = json[1] as String;
    final success = json[2] as bool;
    final message = json.length > 3 ? json[3] as String : '';

    // AUTH flow (unchanged) …
    if (_pendingAuthEvents.containsKey(eventId)) {
      // … existing code untouched …
    }

    // Publish flow (new).
    final pending = _pendingPublishes[eventId];
    if (pending != null) {
      pending.recordOk(relay.url, success, message);
      if (pending.completer.isCompleted) {
        _pendingPublishes.remove(eventId);
      }
    }
  }
}
```

- [ ] **Step 5: Add `sendAwaitOk`**

Add the following method to `RelayPool`, next to `Future<bool> send(...)`:

```dart
/// Sends an EVENT message and returns a [PublishOutcome] reflecting each
/// target relay's NIP-20 OK response. Resolves when every target has
/// responded OR [timeout] elapses.
Future<PublishOutcome> sendAwaitOk(
  Event event, {
  Duration timeout = const Duration(seconds: 15),
  List<String>? tempRelays,
  List<String>? targetRelays,
}) async {
  assert(
    event.id.isNotEmpty && event.sig.isNotEmpty,
    'sendAwaitOk requires a signed event',
  );

  // Determine the full target relay set that will actually receive the
  // frame. We need this before calling send() so pending completer knows
  // which relays to wait on.
  final targets = <String>{};
  for (final relay in _relaysSnapshot()) {
    if (!relay.relayStatus.writeAccess) continue;
    if (targetRelays != null &&
        targetRelays.isNotEmpty &&
        !targetRelays.contains(relay.url)) {
      continue;
    }
    targets.add(relay.url);
  }
  if (tempRelays != null) targets.addAll(tempRelays);

  if (targets.isEmpty) {
    return PublishOutcome(
      eventId: event.id,
      acceptedBy: const {},
      rejectedBy: const {},
      noResponseFrom: const {},
    );
  }

  final pending = _PendingPublish(
    eventId: event.id,
    targetRelays: targets,
    timeout: timeout,
  );
  _pendingPublishes[event.id] = pending;

  final submitted = await send(
    ['EVENT', event.toJson()],
    tempRelays: tempRelays,
    targetRelays: targetRelays,
  );

  if (!submitted) {
    // Nothing actually reached a relay — resolve with all targets as
    // no-response immediately rather than waiting for the timeout.
    _pendingPublishes.remove(event.id);
    pending.cancelTimer();
    return PublishOutcome(
      eventId: event.id,
      acceptedBy: const {},
      rejectedBy: const {},
      noResponseFrom: targets,
    );
  }

  return pending.completer.future.whenComplete(() {
    _pendingPublishes.remove(event.id);
  });
}
```

- [ ] **Step 6: Add test-only surface**

Still in `relay_pool.dart`, add below `sendAwaitOk`:

```dart
@visibleForTesting
void addRelay(Relay relay) {
  _relays[relay.url] = relay;
  relay.onMessage = _onEvent;
}

@visibleForTesting
int get pendingPublishCountForTesting => _pendingPublishes.length;

@visibleForTesting
void handleMessageForTesting(Relay relay, List<dynamic> message) {
  _onEvent(relay, message);
}
```

Ensure `meta` is imported at the top (`import 'package:meta/meta.dart';`).

- [ ] **Step 7: Run the tests to verify they pass**

Run: `cd mobile/packages/nostr_sdk && dart test test/relay/relay_pool_publish_ok_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 8: Run the full SDK test suite — verify no regressions**

Run: `cd mobile/packages/nostr_sdk && dart test`
Expected: all existing tests still pass.

- [ ] **Step 9: Commit**

```bash
git add mobile/packages/nostr_sdk/lib/relay/relay_pool.dart \
        mobile/packages/nostr_sdk/test/relay/relay_pool_publish_ok_test.dart
git commit -m "feat(nostr_sdk): RelayPool.sendAwaitOk resolves per-relay NIP-20 acks"
```

---

## Chunk 3: `Nostr.sendEventAwaitOk`

### Task 3.1: Thin wrapper that signs + calls `RelayPool.sendAwaitOk`

**Files:**
- Modify: `mobile/packages/nostr_sdk/lib/nostr.dart`
- Modify: `mobile/packages/nostr_sdk/test/nostr_test.dart` (add a new group; file already exists)

**Background:** `Nostr.sendEvent` at `:179` signs the event if needed and hands off to `_pool.send`. We mirror it with `sendEventAwaitOk` that returns `PublishOutcome` instead of `Event?`.

- [ ] **Step 1: Write the failing tests**

Add this group to `mobile/packages/nostr_sdk/test/nostr_test.dart` (if file does not exist, create it following the pattern in neighboring SDK tests):

```dart
group('Nostr.sendEventAwaitOk', () {
  test('signs unsigned event before publishing', () async {
    // Use a FakeRelayPool that records the message it receives and
    // returns an OK outcome. Assert that the event passed to the pool
    // has non-empty sig.
    // … (test body — see neighbouring nostr_test.dart for the FakeSigner
    //   and FakeRelayPool setup pattern)
  });

  test('returns empty outcome if signing fails', () async {
    // Signer returns null sig — sendEventAwaitOk must return a
    // PublishOutcome with no accepted/rejected/noResponse entries and
    // NOT call into the pool.
  });

  test('propagates timeout parameter to pool', () async {
    // Assert that the pool's sendAwaitOk was called with the timeout
    // value passed in by the caller (default 15s).
  });
});
```

*Note: this test file uses the existing `FakeRelayPool` / `FakeNostrSigner` helpers already present in `nostr_sdk/test/`. If missing, keep tests as integration smoke tests driven through `Nostr` directly with a minimal stub.*

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd mobile/packages/nostr_sdk && dart test test/nostr_test.dart`
Expected: FAIL — `sendEventAwaitOk` does not exist.

- [ ] **Step 3: Add the method**

Edit `mobile/packages/nostr_sdk/lib/nostr.dart`. Just below `sendEvent` (line 179), add:

```dart
Future<PublishOutcome> sendEventAwaitOk(
  Event event, {
  Duration timeout = const Duration(seconds: 15),
  List<String>? tempRelays,
  List<String>? targetRelays,
}) async {
  if (StringUtil.isBlank(event.sig)) {
    await signEvent(event);
    if (StringUtil.isBlank(event.sig)) {
      return PublishOutcome(
        eventId: event.id,
        acceptedBy: const {},
        rejectedBy: const {},
        noResponseFrom: const {},
      );
    }
  }

  return _pool.sendAwaitOk(
    event,
    timeout: timeout,
    tempRelays: tempRelays,
    targetRelays: targetRelays,
  );
}
```

Add `import 'relay/publish_outcome.dart';` at the top if not already present (transitive through `relay_pool.dart` should cover it, but the explicit import future-proofs refactors).

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd mobile/packages/nostr_sdk && dart test test/nostr_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/nostr_sdk/lib/nostr.dart mobile/packages/nostr_sdk/test/nostr_test.dart
git commit -m "feat(nostr_sdk): Nostr.sendEventAwaitOk wraps RelayPool.sendAwaitOk"
```

---

## Chunk 4: `NostrClient.publishEventAwaitOk`

### Task 4.1: Primitive that preserves existing cache + relay-health behavior

**Files:**
- Modify: `mobile/packages/nostr_client/lib/src/nostr_client.dart`
- Create: `mobile/packages/nostr_client/test/src/publish_event_await_ok_test.dart`

**Background:** `NostrClient.publishEvent` at `:241` already handles optimistic caching, relay health checks with reconnect, and cache rollback on failure. `publishEventAwaitOk` must keep all of that but return `PublishOutcome` and treat `outcome.failed` as the rollback trigger (instead of `sentEvent == null`).

- [ ] **Step 1: Write the failing tests**

Create `mobile/packages/nostr_client/test/src/publish_event_await_ok_test.dart`:

```dart
// ABOUTME: Tests for NostrClient.publishEventAwaitOk — returns PublishOutcome
// ABOUTME: and drives cache rollback when no relay accepts.

import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:test/test.dart';

class _MockNostr extends Mock implements Nostr {}
class _MockRelayManager extends Mock implements RelayManager {}

void main() {
  late _MockNostr nostr;
  late _MockRelayManager relayManager;
  late NostrClient client;

  setUpAll(() {
    registerFallbackValue(
      Event('pk', EventKind.textNote, const [], '')
        ..id = 'x' * 64
        ..sig = 'sig',
    );
  });

  setUp(() {
    nostr = _MockNostr();
    relayManager = _MockRelayManager();
    when(() => relayManager.connectedRelays).thenReturn({'wss://a'});
    client = NostrClient.forTesting(nostr: nostr, relayManager: relayManager);
  });

  Event _event({required int kind, String id = 'a' * 64}) =>
      Event('pk', kind, const [], '')
        ..id = id
        ..sig = 'sig';

  test('returns outcome from Nostr when publish succeeds', () async {
    final event = _event(kind: EventKind.eventDeletion);
    when(
      () => nostr.sendEventAwaitOk(
        any(),
        timeout: any(named: 'timeout'),
        tempRelays: any(named: 'tempRelays'),
        targetRelays: any(named: 'targetRelays'),
      ),
    ).thenAnswer(
      (_) async => PublishOutcome(
        eventId: event.id,
        acceptedBy: const {'wss://a'},
        rejectedBy: const {},
        noResponseFrom: const {},
      ),
    );

    final outcome = await client.publishEventAwaitOk(event);
    expect(outcome.acceptedByAll, isTrue);
    expect(outcome.eventId, event.id);
  });

  test('rolls back optimistic cache when outcome.failed and event is cacheable',
      () async {
    final event = _event(kind: EventKind.textNote); // cacheable regular kind
    when(
      () => nostr.sendEventAwaitOk(
        any(),
        timeout: any(named: 'timeout'),
        tempRelays: any(named: 'tempRelays'),
        targetRelays: any(named: 'targetRelays'),
      ),
    ).thenAnswer(
      (_) async => PublishOutcome(
        eventId: event.id,
        acceptedBy: const {},
        rejectedBy: const {},
        noResponseFrom: const {'wss://a'},
      ),
    );

    final outcome = await client.publishEventAwaitOk(event);
    expect(outcome.failed, isTrue);
    // Expect `_rollbackCachedEvent` to have been invoked — verify through
    // a test seam (e.g. a counter on `NostrClient.forTesting`).
  });

  test('returns all-no-response outcome when no relays are connected',
      () async {
    when(() => relayManager.connectedRelays).thenReturn(<Relay>{});
    when(() => relayManager.retryDisconnectedRelays())
        .thenAnswer((_) async {});
    final event = _event(kind: EventKind.textNote);

    final outcome = await client.publishEventAwaitOk(event);
    expect(outcome.acceptedBy, isEmpty);
    expect(outcome.failed, isTrue);
    verifyNever(
      () => nostr.sendEventAwaitOk(
        any(),
        timeout: any(named: 'timeout'),
        tempRelays: any(named: 'tempRelays'),
        targetRelays: any(named: 'targetRelays'),
      ),
    );
  });

  test('invokes statistics observer with the outcome', () async {
    final event = _event(kind: EventKind.eventDeletion);
    when(
      () => nostr.sendEventAwaitOk(
        any(),
        timeout: any(named: 'timeout'),
        tempRelays: any(named: 'tempRelays'),
        targetRelays: any(named: 'targetRelays'),
      ),
    ).thenAnswer(
      (_) async => PublishOutcome(
        eventId: event.id,
        acceptedBy: const {'wss://a'},
        rejectedBy: const {},
        noResponseFrom: const {},
      ),
    );

    PublishOutcome? captured;
    client.statisticsObserver = _CapturingObserver(
      onOutcome: (outcome) => captured = outcome,
    );

    await client.publishEventAwaitOk(event);
    expect(captured, isNotNull);
    expect(captured!.eventId, event.id);
  });
}

class _CapturingObserver implements NostrClientStatisticsObserver {
  _CapturingObserver({required this.onOutcome});

  final void Function(PublishOutcome) onOutcome;

  @override void onSubscriptionStarted(String _) {}
  @override void onSubscriptionClosed(String _) {}
  @override void onEventReceived() {}
  @override void onEventSent() {}
  @override void onPublishOutcome(PublishOutcome outcome) => onOutcome(outcome);
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd mobile/packages/nostr_client && dart test test/src/publish_event_await_ok_test.dart`
Expected: FAIL — `publishEventAwaitOk` and `onPublishOutcome` do not exist.

- [ ] **Step 3: Extend `NostrClientStatisticsObserver`**

In `mobile/packages/nostr_client/lib/src/nostr_client.dart`, extend the observer interface:

```dart
abstract class NostrClientStatisticsObserver {
  void onSubscriptionStarted(String subscriptionId);
  void onSubscriptionClosed(String subscriptionId);
  void onEventReceived();
  void onEventSent();

  /// Called after a publish attempt resolves via [NostrClient.publishEventAwaitOk]
  /// or [NostrClient.publishEventWithRetry] with the final outcome. Retry
  /// wrappers invoke this once per attempt so observers can measure per-try
  /// latency as well as final result.
  void onPublishOutcome(PublishOutcome outcome) {}
}
```

- [ ] **Step 4: Add `publishEventAwaitOk`**

Right after the existing `publishEvent` method, add:

```dart
/// Publishes [event] and returns a [PublishOutcome] built from per-relay
/// NIP-20 OK acknowledgements. Unlike [publishEvent], resolves only when
/// every targeted relay has accepted/rejected or [timeout] elapses.
///
/// Cache semantics match [publishEvent]:
/// - Regular events: optimistically cached before send; rolled back on
///   [PublishOutcome.failed].
/// - Replaceable and addressable events: cached on success (any relay
///   accept) only.
/// - Deletion events: target events removed from cache on any acceptance.
Future<PublishOutcome> publishEventAwaitOk(
  Event event, {
  Duration timeout = const Duration(seconds: 15),
  List<String>? targetRelays,
}) async {
  final useOptimisticCache = _canOptimisticallyCache(event.kind);
  if (useOptimisticCache) _cacheEvent(event);

  if (_relayManager.connectedRelays.isEmpty) {
    await retryDisconnectedRelays();
    if (_relayManager.connectedRelays.isEmpty) {
      if (useOptimisticCache) _rollbackCachedEvent(event.id);
      final outcome = PublishOutcome(
        eventId: event.id,
        acceptedBy: const {},
        rejectedBy: const {},
        noResponseFrom: const {},
      );
      statisticsObserver?.onPublishOutcome(outcome);
      return outcome;
    }
  }

  final outcome = await _nostr.sendEventAwaitOk(
    event,
    timeout: timeout,
    targetRelays: targetRelays,
    tempRelays: targetRelays,
  );

  if (outcome.failed) {
    if (useOptimisticCache) _rollbackCachedEvent(event.id);
  } else {
    if (event.kind == EventKind.eventDeletion) {
      _handleDeletionEvent(event);
    } else if (!useOptimisticCache) {
      _cacheEvent(event);
    }
    statisticsObserver?.onEventSent();
  }

  statisticsObserver?.onPublishOutcome(outcome);
  return outcome;
}
```

- [ ] **Step 5: Export types from the package barrel**

In `mobile/packages/nostr_client/lib/nostr_client.dart`, add:

```dart
export 'package:nostr_sdk/relay/publish_outcome.dart' show PublishOutcome;
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `cd mobile/packages/nostr_client && dart test test/src/publish_event_await_ok_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 7: Run the full nostr_client suite — verify no regressions**

Run: `cd mobile/packages/nostr_client && dart test`
Expected: existing tests still pass.

- [ ] **Step 8: Commit**

```bash
git add mobile/packages/nostr_client/lib/src/nostr_client.dart \
        mobile/packages/nostr_client/lib/nostr_client.dart \
        mobile/packages/nostr_client/test/src/publish_event_await_ok_test.dart
git commit -m "feat(nostr_client): NostrClient.publishEventAwaitOk + PublishOutcome export"
```

---

## Chunk 5: `RetryPolicy` and `publishEventWithRetry`

### Task 5.1: Policy config

**Files:**
- Create: `mobile/packages/nostr_client/lib/src/retry_policy.dart`

- [ ] **Step 1: Define the type**

Create `mobile/packages/nostr_client/lib/src/retry_policy.dart`:

```dart
// ABOUTME: Retry policy for Nostr publishes — bounded attempts with
// ABOUTME: exponential backoff, retrying only transient relays per NIP-01.

import 'package:meta/meta.dart';

@immutable
class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(seconds: 2),
    this.timeoutPerAttempt = const Duration(seconds: 15),
    this.maxDelay = const Duration(seconds: 30),
  });

  /// Maximum attempts including the initial try. 3 means initial + 2 retries.
  final int maxAttempts;

  /// Delay before the 2nd attempt. Doubles each retry up to [maxDelay].
  final Duration baseDelay;

  /// Per-attempt publish timeout forwarded to `publishEventAwaitOk`.
  final Duration timeoutPerAttempt;

  /// Cap on the delay between attempts.
  final Duration maxDelay;

  Duration delayFor(int attemptIndex) {
    // attemptIndex is 1 for the first retry (2nd attempt), 2 for the next,…
    final millis = baseDelay.inMilliseconds * (1 << (attemptIndex - 1));
    final capped =
        millis > maxDelay.inMilliseconds ? maxDelay.inMilliseconds : millis;
    return Duration(milliseconds: capped);
  }
}
```

- [ ] **Step 2: Export from the barrel**

Add to `mobile/packages/nostr_client/lib/nostr_client.dart`:

```dart
export 'src/retry_policy.dart';
```

### Task 5.2: `publishEventWithRetry`

**Files:**
- Modify: `mobile/packages/nostr_client/lib/src/nostr_client.dart`
- Create: `mobile/packages/nostr_client/test/src/publish_event_with_retry_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `mobile/packages/nostr_client/test/src/publish_event_with_retry_test.dart`:

```dart
// ABOUTME: Tests for NostrClient.publishEventWithRetry — retries only
// ABOUTME: noResponse + transient-rejected relays, surrenders on all-permanent.

import 'package:fake_async/fake_async.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:test/test.dart';

// Reuse _MockNostr + _MockRelayManager setup from publish_event_await_ok_test.

void main() {
  group('publishEventWithRetry', () {
    test('returns after first attempt when acceptedByAll', () async {
      // sendEventAwaitOk returns accepted-by-all → no retry.
      // Verify sendEventAwaitOk called exactly once.
    });

    test('retries only the noResponse + transient relays', () async {
      // 1st outcome: accepted by {a}, transient rejected by {b}, no-response {c}.
      // 2nd attempt should be invoked with targetRelays=={b,c}.
    });

    test('does not retry when all rejections are permanent', () async {
      // rejectedBy = {a: "blocked: spam", b: "invalid: sig"}
      // noResponseFrom empty. Must stop after attempt 1 (no transient relays).
    });

    test('surrenders after maxAttempts exhaustion', () async {
      // All 3 attempts fail with no response. Final outcome returned, never
      // retries past maxAttempts.
    });

    test('delays between attempts follow exponential schedule', () async {
      // Use fake_async to assert elapsed time between attempts is
      // baseDelay, 2*baseDelay, capped at maxDelay.
    });

    test('emits onPublishOutcome once per attempt', () async {
      // Observer sees N invocations for N attempts.
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd mobile/packages/nostr_client && dart test test/src/publish_event_with_retry_test.dart`
Expected: FAIL — `publishEventWithRetry` undefined.

- [ ] **Step 3: Implement the method**

In `NostrClient`, below `publishEventAwaitOk`:

```dart
/// Publishes with bounded retry on transient failure. Retries only
/// relays in `outcome.transientRelays`. Stops as soon as
/// [PublishOutcome.acceptedByAny] OR all attempts exhausted.
///
/// Each attempt is timed out individually by [RetryPolicy.timeoutPerAttempt].
/// The returned outcome is the **last** attempt's outcome (so rejectedBy
/// relays that went permanent in a later attempt surface correctly).
Future<PublishOutcome> publishEventWithRetry(
  Event event, {
  RetryPolicy policy = const RetryPolicy(),
  List<String>? targetRelays,
}) async {
  PublishOutcome outcome = await publishEventAwaitOk(
    event,
    timeout: policy.timeoutPerAttempt,
    targetRelays: targetRelays,
  );

  for (var attempt = 1; attempt < policy.maxAttempts; attempt++) {
    if (outcome.acceptedByAny) return outcome;
    final retryTargets = outcome.transientRelays;
    if (retryTargets.isEmpty) return outcome;

    await Future<void>.delayed(policy.delayFor(attempt));

    outcome = await publishEventAwaitOk(
      event,
      timeout: policy.timeoutPerAttempt,
      targetRelays: retryTargets.toList(),
    );
  }
  return outcome;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd mobile/packages/nostr_client && dart test test/src/publish_event_with_retry_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/nostr_client/lib/src/retry_policy.dart \
        mobile/packages/nostr_client/lib/src/nostr_client.dart \
        mobile/packages/nostr_client/lib/nostr_client.dart \
        mobile/packages/nostr_client/test/src/publish_event_with_retry_test.dart
git commit -m "feat(nostr_client): publishEventWithRetry with exponential backoff"
```

---

## Chunk 6: `PublishResultMapper`

### Task 6.1: Outcome → user feedback

**Files:**
- Create: `mobile/packages/nostr_client/lib/src/publish_result_mapper.dart`
- Create: `mobile/packages/nostr_client/test/src/publish_result_mapper_test.dart`

**Background:** Every service migration (deletion, profile, follow list, etc.) needs the same outcome → user UX decision:
- All accepted → silent success / localized "Published"
- Partially accepted → silent success (the event is durable on at least one relay)
- All permanent rejections → localized "Can't publish: <reason>" (non-retryable)
- All transient → localized "Couldn't reach any relay" (retryable)

Keeping this logic in one place means every service domain maps outcome → snackbar via the same contract.

- [ ] **Step 1: Write the failing tests**

Create `mobile/packages/nostr_client/test/src/publish_result_mapper_test.dart`:

```dart
// ABOUTME: Tests for PublishResultMapper — canonical outcome → UX decision.

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:test/test.dart';

void main() {
  group(PublishResultMapper, () {
    test('accepted by all → success, not retryable', () {
      final fb = PublishResultMapper.map(
        PublishOutcome(
          eventId: 'a' * 64,
          acceptedBy: const {'wss://a', 'wss://b'},
          rejectedBy: const {},
          noResponseFrom: const {},
        ),
      );
      expect(fb.severity, PublishSeverity.success);
      expect(fb.retryable, isFalse);
      expect(fb.messageKey, 'publish_success');
    });

    test('partial accept → success (durable on one relay)', () {
      final fb = PublishResultMapper.map(
        PublishOutcome(
          eventId: 'a' * 64,
          acceptedBy: const {'wss://a'},
          rejectedBy: const {'wss://b': 'blocked: banned'},
          noResponseFrom: const {'wss://c'},
        ),
      );
      expect(fb.severity, PublishSeverity.success);
      expect(fb.retryable, isFalse);
    });

    test('all transient → error, retryable', () {
      final fb = PublishResultMapper.map(
        PublishOutcome(
          eventId: 'a' * 64,
          acceptedBy: const {},
          rejectedBy: const {},
          noResponseFrom: const {'wss://a', 'wss://b'},
        ),
      );
      expect(fb.severity, PublishSeverity.error);
      expect(fb.retryable, isTrue);
      expect(fb.messageKey, 'publish_no_relay_response');
    });

    test('all permanent rejects → error, NOT retryable', () {
      final fb = PublishResultMapper.map(
        PublishOutcome(
          eventId: 'a' * 64,
          acceptedBy: const {},
          rejectedBy: const {
            'wss://a': 'blocked: user',
            'wss://b': 'invalid: sig',
          },
          noResponseFrom: const {},
        ),
      );
      expect(fb.severity, PublishSeverity.error);
      expect(fb.retryable, isFalse);
      expect(fb.messageKey, 'publish_rejected_permanent');
      expect(fb.firstRejectionReason, anyOf('blocked: user', 'invalid: sig'));
    });

    test('empty outcome (no targets) → error, retryable', () {
      final fb = PublishResultMapper.map(
        PublishOutcome(
          eventId: 'a' * 64,
          acceptedBy: const {},
          rejectedBy: const {},
          noResponseFrom: const {},
        ),
      );
      expect(fb.severity, PublishSeverity.error);
      expect(fb.retryable, isTrue);
      expect(fb.messageKey, 'publish_no_relays_available');
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd mobile/packages/nostr_client && dart test test/src/publish_result_mapper_test.dart`
Expected: FAIL — type undefined.

- [ ] **Step 3: Implement the mapper**

Create `mobile/packages/nostr_client/lib/src/publish_result_mapper.dart`:

```dart
// ABOUTME: Maps a PublishOutcome to PublishUserFeedback — single source of
// ABOUTME: truth for how every service domain translates publish results into UX.

import 'package:meta/meta.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';

enum PublishSeverity { success, error }

@immutable
class PublishUserFeedback {
  const PublishUserFeedback({
    required this.severity,
    required this.messageKey,
    required this.retryable,
    this.firstRejectionReason,
  });

  final PublishSeverity severity;

  /// i18n key — consumers look this up in their l10n ARB. Keeps the mapper
  /// free of translation deps.
  final String messageKey;

  /// Whether retrying has a reasonable chance of succeeding. UIs should
  /// expose a retry affordance only when true.
  final bool retryable;

  /// First raw rejection reason (if any) — useful for debug logs.
  final String? firstRejectionReason;
}

abstract class PublishResultMapper {
  PublishResultMapper._();

  static PublishUserFeedback map(PublishOutcome outcome) {
    if (outcome.acceptedByAny) {
      return const PublishUserFeedback(
        severity: PublishSeverity.success,
        messageKey: 'publish_success',
        retryable: false,
      );
    }

    if (outcome.acceptedBy.isEmpty &&
        outcome.rejectedBy.isEmpty &&
        outcome.noResponseFrom.isEmpty) {
      return const PublishUserFeedback(
        severity: PublishSeverity.error,
        messageKey: 'publish_no_relays_available',
        retryable: true,
      );
    }

    if (outcome.transientRelays.isNotEmpty) {
      return const PublishUserFeedback(
        severity: PublishSeverity.error,
        messageKey: 'publish_no_relay_response',
        retryable: true,
      );
    }

    final firstReason = outcome.rejectedBy.values.isNotEmpty
        ? outcome.rejectedBy.values.first
        : null;
    return PublishUserFeedback(
      severity: PublishSeverity.error,
      messageKey: 'publish_rejected_permanent',
      retryable: false,
      firstRejectionReason: firstReason,
    );
  }
}
```

- [ ] **Step 4: Export from the barrel**

In `mobile/packages/nostr_client/lib/nostr_client.dart`, add:

```dart
export 'src/publish_result_mapper.dart';
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd mobile/packages/nostr_client && dart test test/src/publish_result_mapper_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
git add mobile/packages/nostr_client/lib/src/publish_result_mapper.dart \
        mobile/packages/nostr_client/lib/nostr_client.dart \
        mobile/packages/nostr_client/test/src/publish_result_mapper_test.dart
git commit -m "feat(nostr_client): PublishResultMapper for consistent publish UX"
```

---

## Chunk 7: Reference migration — `ContentDeletionService`

### Task 7.1: Expand `DeleteResult` to carry the outcome

**Files:**
- Modify: `mobile/lib/services/content_deletion_service.dart`

**Background:** Today `DeleteResult.success` is `true` the moment `publishEvent` returns a non-null `Event?`, which only means "the WebSocket sink accepted the frame". It does not mean any relay durably stored it. Future Apple-App-Store-compliance audits have asked for stronger guarantees. We now set `success = outcome.acceptedByAny` and expose the full outcome so UI callers can distinguish partial/permanent/transient failures.

- [ ] **Step 1: Add an `outcome` field to `DeleteResult`**

Edit the top of `content_deletion_service.dart`:

```dart
import 'package:nostr_client/nostr_client.dart'; // already present

class DeleteResult {
  const DeleteResult({
    required this.success,
    required this.timestamp,
    this.error,
    this.deleteEventId,
    this.outcome,
    this.feedback,
  });
  final bool success;
  final String? error;
  final String? deleteEventId;
  final DateTime timestamp;
  final PublishOutcome? outcome;
  final PublishUserFeedback? feedback;

  static DeleteResult createSuccess({
    required String deleteEventId,
    required PublishOutcome outcome,
    required PublishUserFeedback feedback,
  }) =>
      DeleteResult(
        success: true,
        deleteEventId: deleteEventId,
        outcome: outcome,
        feedback: feedback,
        timestamp: DateTime.now(),
      );

  static DeleteResult failure({
    required String error,
    PublishOutcome? outcome,
    PublishUserFeedback? feedback,
  }) =>
      DeleteResult(
        success: false,
        error: error,
        outcome: outcome,
        feedback: feedback,
        timestamp: DateTime.now(),
      );
}
```

### Task 7.2: Replace `publishEvent` with `publishEventWithRetry`

- [ ] **Step 1: Write failing test**

Create `mobile/test/unit/services/content_deletion_service_reliability_test.dart`:

```dart
// ABOUTME: Tests that ContentDeletionService uses publishEventWithRetry
// ABOUTME: and surfaces the outcome via DeleteResult.

import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}
class _MockAuthService extends Mock implements AuthService {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      Event('pk', EventKind.eventDeletion, const [], '')..id = 'x' * 64..sig = 'sig',
    );
    registerFallbackValue(const RetryPolicy());
  });

  late _MockNostrClient nostr;
  late _MockAuthService auth;

  setUp(() async {
    nostr = _MockNostrClient();
    auth = _MockAuthService();
    SharedPreferences.setMockInitialValues({});
    when(() => nostr.isInitialized).thenReturn(true);
  });

  test('success when at least one relay accepts', () async {
    final prefs = await SharedPreferences.getInstance();
    final service =
        ContentDeletionService(nostrService: nostr, authService: auth, prefs: prefs);
    await service.initialize();

    // … stub _createDeleteEvent to return a signed Event (via auth.createAndSignEvent)
    // … stub publishEventWithRetry to return an accepted-by-one outcome
    // … assert result.success is true
    // … assert result.outcome.acceptedBy contains the relay
    // … assert result.feedback.severity == success
  });

  test('failure with retryable feedback when all relays silent', () async {
    // … stub publishEventWithRetry to return all-no-response outcome
    // … assert result.success is false
    // … assert result.feedback.retryable is true
    // … assert result.feedback.messageKey == publish_no_relay_response
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

Run: `cd mobile && flutter test test/unit/services/content_deletion_service_reliability_test.dart`
Expected: FAIL — service still calls `publishEvent`.

- [ ] **Step 3: Update the service**

Replace the body of `deleteContent` around line 150 in `content_deletion_service.dart`:

```dart
final outcome = await _nostrService.publishEventWithRetry(deleteEvent);
final feedback = PublishResultMapper.map(outcome);

if (outcome.acceptedByAny) {
  Log.info(
    'Delete request published (acceptedBy=${outcome.acceptedBy})',
    name: 'ContentDeletionService',
    category: LogCategory.system,
  );

  final deletion = ContentDeletion(
    deleteEventId: deleteEvent.id,
    originalEventId: video.id,
    reason: reason,
    deletedAt: DateTime.now(),
    additionalContext: additionalContext,
  );
  _deletionHistory.add(deletion);
  await _saveDeletionHistory();

  return DeleteResult.createSuccess(
    deleteEventId: deleteEvent.id,
    outcome: outcome,
    feedback: feedback,
  );
}

Log.error(
  'Delete request failed: ${outcome.toString()}',
  name: 'ContentDeletionService',
  category: LogCategory.system,
);
return DeleteResult.failure(
  error: 'Failed to publish delete request',
  outcome: outcome,
  feedback: feedback,
);
```

Remove the legacy "save locally even if publish fails" branch — previously we saved deletion history even when the relay never heard about it, which leaves the UI believing the video is gone while the event remains reachable from every other client. Durable deletion requires at least one relay accept.

- [ ] **Step 4: Run tests to confirm they pass**

Run: `cd mobile && flutter test test/unit/services/content_deletion_service_reliability_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the existing content_deletion_service tests**

Run: `cd mobile && flutter test test/unit/services/content_deletion_service_test.dart`
Expected: PASS — any test depending on the "save locally even on failure" branch needs updating in this step to reflect the new contract.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/services/content_deletion_service.dart \
        mobile/test/unit/services/content_deletion_service_reliability_test.dart \
        mobile/test/unit/services/content_deletion_service_test.dart
git commit -m "feat(deletion): publishEventWithRetry + PublishOutcome surfaced on DeleteResult"
```

---

## Chunk 8: UI wiring — `share_video_menu.dart` delete flow

### Task 8.1: Consume `DeleteResult.feedback` in the UI

**Files:**
- Modify: `mobile/lib/widgets/share_video_menu.dart`

**Background:** The delete flow in `share_video_menu.dart` (`_deleteVideo` around `:1789`) currently shows "Video deletion requested" on `result.success` — which, before this PR, was true even when no relay heard about the event. We now use `PublishResultMapper` via `result.feedback` to drive the snackbar and, when `feedback.retryable` is true, offer a Retry action.

- [ ] **Step 1: Update the UI**

Replace the snackbar block in `_deleteVideo`:

```dart
if (!mounted) return;
context.pop(); // Close edit dialog

final feedback = result.feedback;
if (result.success) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Video deletion requested'),
      backgroundColor: VineTheme.vineGreen,
    ),
  );
} else {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(_copyForFeedback(feedback)),
      backgroundColor: VineTheme.error,
      action: feedback?.retryable == true
          ? SnackBarAction(
              label: 'Retry',
              onPressed: _deleteVideo,
            )
          : null,
    ),
  );
}
```

Add the helper near the bottom of the state class:

```dart
String _copyForFeedback(PublishUserFeedback? feedback) {
  if (feedback == null) return 'Failed to delete video';
  // l10n lookup lives with the full migration PR that adds the ARB keys.
  // For PR 1, we ship a switch returning English copy — PRs 2+ will drop
  // this in favor of AppLocalizations.of(context).<key>.
  switch (feedback.messageKey) {
    case 'publish_no_relay_response':
      return 'Could not reach any relay. Check your connection and try again.';
    case 'publish_rejected_permanent':
      return 'Delete request rejected: ${feedback.firstRejectionReason ?? "unknown reason"}';
    case 'publish_no_relays_available':
      return 'No relays available. Try again later.';
    default:
      return 'Failed to delete video';
  }
}
```

- [ ] **Step 2: Add a widget test**

Extend (or create) `mobile/test/widgets/share_video_menu_delete_test.dart` with a test that:
1. Mocks `contentDeletionServiceProvider` to return a `DeleteResult.failure` with `feedback.retryable == true`.
2. Pumps the delete dialog and taps "Delete".
3. Asserts a `SnackBar` appears with the transient copy and a "Retry" action.
4. Taps Retry and asserts `quickDelete` is called a second time.

- [ ] **Step 3: Run widget test**

Run: `cd mobile && flutter test test/widgets/share_video_menu_delete_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/widgets/share_video_menu.dart \
        mobile/test/widgets/share_video_menu_delete_test.dart
git commit -m "feat(delete-ui): retry-able failure snackbar via PublishResultMapper"
```

---

## Chunk 9: Verification

### Task 9.1: Static analysis

- [ ] **Step 1: Run analyzer across changed packages**

Run:
```bash
cd mobile && flutter analyze lib test
(cd packages/nostr_sdk && dart analyze)
(cd packages/nostr_client && dart analyze)
```
Expected: zero issues.

### Task 9.2: Full test suite

- [ ] **Step 1: Run all related test suites**

Run:
```bash
(cd mobile/packages/nostr_sdk && dart test)
(cd mobile/packages/nostr_client && dart test)
(cd mobile && flutter test test/unit/services/content_deletion_service_reliability_test.dart \
                     test/unit/services/content_deletion_service_test.dart \
                     test/widgets/share_video_menu_delete_test.dart)
```
Expected: all PASS.

### Task 9.3: Pre-commit parity

Per `.claude/rules/git_hooks.md`, confirm the pre-push hook runs clean.

- [ ] **Step 1: Verify hooks are installed**

Run: `ls mobile/.git/hooks/pre-commit mobile/.git/hooks/pre-push`
If missing: `cd mobile && mise run setup_hooks`.

- [ ] **Step 2: Dry-run a hook**

Run: `cd mobile && mise exec -- flutter analyze lib test integration_test`
Expected: zero issues.

### Task 9.4: Push and open PR

- [ ] **Step 1: Push branch**

Run: `git push -u origin feat/reliable-nostr-publish`

- [ ] **Step 2: Open PR**

Use `/pr-summary` skill or manually:

```
Title: feat(nostr): reliable publish primitives + NIP-09 deletion migration

Body:
## Summary
- Adds `PublishOutcome`, `NostrClient.publishEventAwaitOk`, `publishEventWithRetry`
  with exponential backoff and transient-only retry.
- Adds `PublishResultMapper` so every future service migration maps outcome →
  user feedback uniformly.
- Migrates `ContentDeletionService` as the reference implementation; the delete
  snackbar in `share_video_menu.dart` now shows an actionable Retry on transient
  failures.
- No behavioural change for the 28 other publish call sites — those migrate in
  PRs 2-8 (tracked in a follow-up plan doc).

## Test plan
- [ ] `dart test` in `packages/nostr_sdk` and `packages/nostr_client` — PASS
- [ ] `flutter test` on migrated service + widget tests — PASS
- [ ] Manually delete a video on a staging relay that drops OK frames — expect
      retry snackbar with Retry action
- [ ] Manually delete on a relay that returns `blocked:` — expect non-retryable
      snackbar with the reason
```

---

## Scope not included in PR 1 (tracked for later plans)

The 28 remaining publish call sites migrate in these follow-up plans, each in its own worktree and PR:

- **PR 2 — `video-publish-reliability`**: `video_event_publisher.dart`, `share_video_menu.dart` rebroadcast.
- **PR 3 — `social-graph-reliability`**: `social_service.dart`, `base/social_event_service_base.dart`, `comments_repository`, `NostrClient.sendLike` / `deleteEvent` paths.
- **PR 4 — `moderation-reliability`**: `mute_service.dart`, `content_blocklist_service.dart`, `content_reporting_service.dart`.
- **PR 5 — `lists-reliability`**: `bookmark_service.dart`, `curated_list_service.dart`, `curation_service.dart`, `account_label_service.dart`.
- **PR 6 — `dm-reliability`**: `dm_repository.dart`, `nip17_message_service.dart`.
- **PR 7 — `account-deletion-reliability`**: `account_deletion_service.dart`.
- **PR 8 — `cleanup-legacy-publishes`**: deprecate `video_sharing_service.dart` NIP-04 share, leave `corrupted_video_repair_service.dart` fire-and-forget.

Each follow-up plan uses the PR-1 primitives (`publishEventWithRetry`, `PublishResultMapper`) directly — they don't add new shared infrastructure. They each:
1. Replace `publishEvent` call with `publishEventWithRetry`.
2. Thread the outcome through the calling BLoC/Cubit/state.
3. Wire the UI to `PublishResultMapper` — snackbars, loading states, retry actions.
4. Add service-specific tests covering OK / reject / timeout paths.

---

## Risks and mitigations

- **OK frame key collision between AUTH and publish.** AUTH events' ids are tracked in `_pendingAuthEvents` (existing) and publish events' ids in `_pendingPublishes` (new). Since we use event.id as the key and AUTH events have their own generated ids, collision requires an astronomical hash collision. No mitigation needed beyond existing checks.
- **Self-wrap publishes (kind 1059 to self) don't need to block on relay OK.** PR 6 will handle that; PR 1 keeps the self-wrap flow on the plain `publishEvent`.
- **Relays that never send OK at all.** The default 15s timeout surfaces as no-response; retry handles transient, and `PublishResultMapper.map` flags retryable. No permanent lock-up.
- **Cache rollback on partial success.** `publishEventAwaitOk` only rolls back when `outcome.failed` (zero accepts). Partial accepts keep the cache — that matches the existing `publishEvent` semantics where any single relay success is treated as durable.
