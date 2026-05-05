---
name: dart-lifecycle-disposed-flag-overload
description: |
  Fix Dart/Flutter services where calling start() after stop() is a silent no-op
  because stop() sets a _disposed (or similar) flag that start()'s guard short-circuits
  on. Use when: (1) A repository/service/controller has startListening/stopListening,
  subscribe/unsubscribe, open/close, or similar lifecycle methods, (2) Re-opening
  the service after closing it appears to do nothing — no subscription, no events,
  no error, (3) Unit tests that only exercise a single mount/open/start cycle pass
  while the real app breaks on the second visit to a screen, (4) A boolean flag
  is used both for "in the middle of tearing down this instance forever" AND for
  "currently stopped, can be re-started". Common in Riverpod/Bloc-driven screens
  that wire startListening() in initState and stopListening() in dispose — the
  second time the user visits the screen, nothing happens.
author: Claude Code
version: 1.0.0
date: 2026-04-05
---

# Dart Lifecycle `_disposed` Flag Overload

## Problem

A Dart/Flutter class with start/stop lifecycle methods sets a "disposed"/"stopped"
boolean inside `stop()`, but the guard clause in `start()` short-circuits whenever
that boolean is true. After a stop→start cycle, `start()` silently returns without
doing anything. The class has two distinct concerns conflated into one flag:

1. **"This instance is permanently torn down"** (e.g. user switched accounts, object
   is being discarded) — should prevent any further work.
2. **"Currently not listening, but could be re-started"** (e.g. user navigated away
   from the inbox screen and may come back) — must allow future `start()` calls.

When those concerns share a single flag, the second concern silently breaks the
first.

## Context / Trigger Conditions

- A class (repository, service, controller, bloc, cubit, notifier) has methods like:
  - `startListening()` / `stopListening()`
  - `subscribe()` / `unsubscribe()`
  - `connect()` / `disconnect()`
  - `open()` / `close()`
- `stop()` includes a line like `_disposed = true;` or `_stopped = true;`
- `start()` begins with a guard like:
  ```dart
  if (_subscription != null || _disposed || !isInitialized) return;
  ```
- Symptom: the feature works on first open, breaks on every subsequent open
- Unit tests that mock the dependencies pass because they only exercise one cycle
  OR because the mock doesn't model the real instance's internal state
- Manual QA finds that leaving and returning to a screen breaks the feature silently
  (no error thrown, no log emitted, no visible indication)

## Solution

**Separate the two concerns.** Reserve the permanent-teardown flag for the code path
that actually tears the instance down for good (typically a `_resetState()` called on
user-switch or full logout), and do NOT set it inside `stop()`.

### Before (broken)

```dart
class MyRepository {
  bool _disposed = false;
  StreamSubscription<Event>? _subscription;

  void startListening() {
    if (_subscription != null || _disposed || !isInitialized) return;
    _subscription = _client.subscribe(...).listen(...);
  }

  Future<void> stopListening() async {
    _disposed = true;                    // ← THE BUG
    await _subscription?.cancel();
    _subscription = null;
  }

  void _resetState() {
    _disposed = true;
    // ... wipe credentials ...
    _disposed = false;
  }
}
```

After `stopListening()`, `_disposed == true` forever until `_resetState()` is called
(which only happens on user switch). Any subsequent `startListening()` hits the guard
and returns silently.

### After (fixed)

```dart
class MyRepository {
  bool _disposed = false;
  StreamSubscription<Event>? _subscription;

  void startListening() {
    // Guard still checks _disposed for the permanent-teardown case — that
    // window is only open during _resetState()'s synchronous body.
    if (_subscription != null || _disposed || !isInitialized) return;
    _subscription = _client.subscribe(...).listen(...);
  }

  Future<void> stopListening() async {
    // Do NOT set _disposed here — _disposed is reserved for _resetState()
    // (permanent teardown, e.g. user switch). Setting it would make a
    // subsequent startListening() call a silent no-op and break re-open
    // flows like "user leaves the screen and comes back later".
    await _subscription?.cancel();
    _subscription = null;
  }

  void _resetState() {
    _disposed = true;
    // ... wipe credentials, cancel subscription, etc. ...
    _disposed = false;
  }
}
```

The `_subscription != null` half of the guard is still sufficient to make
`startListening()` idempotent against double-calls within a single listening lifetime.

## Verification

1. **Add a regression test** that exercises start → stop → start and asserts the
   start work happened twice:

   ```dart
   test('startListening after stopListening re-opens the subscription', () async {
     final repo = createRepository();
     repo.initialize(...);

     repo.startListening();
     await repo.stopListening();
     repo.startListening();

     // Both opens must hit the client.
     verify(() => mockClient.subscribe(any(), ...)).called(2);

     await repo.stopListening();
   });
   ```

2. **Manual QA:** visit the screen that drives the lifecycle, back out of it,
   visit it again. The feature should work on the second visit identically to
   the first.

3. **Run the existing test for the permanent-teardown path** (e.g. user switch /
   `_resetState()`) and confirm it still passes. The fix should not affect that path.

## Example

From divine-mobile (PR #2769, April 2026): `DmRepository` drove NIP-17 gift-wrap
subscription lifecycle from the inbox screen's `initState`/`dispose`. On the second
visit to the inbox, DMs silently stopped arriving. Root cause: `stopListening()` had
`_disposed = true;` as its first line. Fix: delete that line, leave an explanatory
comment, add a regression test that asserts `mockNostrClient.subscribe` was called
twice after an open → close → open cycle. Commit
`bd1420eb3 fix(dm): allow startListening() to succeed after stopListening()`.

## Notes

- **Why mocks hide this bug:** unit tests that mock the dependency (e.g. a mock
  `NostrClient`) only verify that the repository calls `subscribe()` once when
  `startListening()` is called. They don't exercise the real state machine across
  multiple cycles unless the test explicitly cycles start→stop→start and verifies
  the second start also called `subscribe`. Add that cycle to your lifecycle test
  suite preemptively.
- **Alternative name for the flag:** if you need two flags because both concerns
  genuinely exist, name them for their actual meaning: `_permanentlyDisposed` (or
  `_torn_down`) vs `_isListening` (or `_started`). A single `bool` with an overloaded
  meaning is the root smell.
- **Riverpod/Bloc lifecycle binding:** this bug is especially common when a screen
  wires `startListening()` in `initState` and `stopListening()` in `dispose` and
  the user can leave and return to the screen. If that flow is new, always add a
  "visit twice" test to your widget test for that screen.
- **Watch for asymmetric reconnect paths:** `onDone` callbacks on cancelled streams
  may also read the flag and decide whether to schedule a reconnect. After separating
  the flags, audit every read of the old flag to confirm the new semantics still
  match the callsite's intent.

## References

- Dart `StreamSubscription.cancel()` docs: https://api.dart.dev/stable/dart-async/StreamSubscription/cancel.html
  (cancellation does not deliver a `done` event to the listener, which is relevant
  when auditing onDone reconnect paths after this fix.)
- Flutter lifecycle (`State.initState` / `State.dispose`): https://api.flutter.dev/flutter/widgets/State-class.html
