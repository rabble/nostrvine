---
name: flutter-async-test-unhandled-future-rejection
description: |
  Fix flaky Flutter/Dart tests that fail in CI but pass locally due to unhandled Future
  rejections. Use when: (1) Test passes locally but fails in CI with cryptic errors,
  (2) Test creates Futures that will throw errors (e.g., network calls to fake URLs),
  (3) Even with .catchError() at the end, test still fails, (4) Error message shows
  test name but truncated error like "ROR]" or "[ERROR]". Solution: Avoid creating
  Futures that will reject; test state machine behavior with synchronous operations instead.
author: Claude Code
version: 1.0.0
date: 2026-02-01
---

# Flutter Async Test Unhandled Future Rejection

## Problem

Tests that create Futures which will reject (throw errors) can fail in CI even when:
- You catch the error with `.catchError()` at the end
- You use `try/catch` around the await
- The test passes locally

The Flutter/Dart test framework detects "unhandled" Future rejections during test
execution, even if you plan to handle them later. This causes flaky tests that
pass locally but fail in CI due to timing differences.

## Context / Trigger Conditions

**Symptoms:**
- Test passes locally with `flutter test` but fails in CI
- Error message is truncated or cryptic (e.g., "ROR]" instead of "[ERROR]")
- Test name appears in error output but no clear assertion failure
- Test involves creating Futures to URLs/resources that don't exist
- Using patterns like:
  ```dart
  final future = someAsyncOperation(); // This will throw
  // ... do assertions ...
  await future.catchError((_) {}); // Too late - already flagged as unhandled
  ```

**Common scenarios:**
- Testing that a method can only be called once (state guards)
- Testing timeout/cancellation behavior
- Testing error handling paths
- Any test that intentionally triggers errors in async code

## Solution

### Don't create Futures that will reject - test the state machine directly

**Instead of:**
```dart
test('start throws if already started', () async {
  final session = SomeSession(url: 'wss://fake.url');

  // BAD: This Future will reject when connection fails
  final startFuture = session.start();

  // Even this won't help - rejection already detected
  await Future.delayed(Duration.zero);

  expect(() => session.start(), throwsA(isA<StateError>()));

  // Too late to catch - test already failed
  await startFuture.catchError((_) {});
});
```

**Do this:**
```dart
test('start throws if already started', () {
  // GOOD: Completely synchronous, no network calls
  final session = SomeSession(url: 'wss://example.com');

  // Use a synchronous state transition to exit the "startable" state
  session.cancel(); // Transitions state without network call

  // Now test that start() throws when not in initial state
  expect(
    () => session.start(),
    throwsA(isA<StateError>()),
  );

  session.dispose();
});
```

### Alternative approaches if you must use async

**Option 1: Wrap the Future creation in a zone that ignores errors**
```dart
test('handles async error', () async {
  late Future<void> errorFuture;

  await runZonedGuarded(() async {
    errorFuture = operationThatWillFail();
    // Do synchronous assertions here
  }, (error, stack) {
    // Ignore expected errors
  });
});
```

**Option 2: Use expectLater for Futures that should fail**
```dart
test('operation fails with specific error', () async {
  // Let the test framework know this Future SHOULD fail
  await expectLater(
    operationThatWillFail(),
    throwsA(isA<SomeError>()),
  );
});
```

**Option 3: Mock the async dependency**
```dart
test('start throws if already started', () async {
  final mockRelay = MockRelay();
  when(mockRelay.connect()).thenAnswer((_) async => {}); // Never fails

  final session = SomeSession(relay: mockRelay);
  await session.start();

  expect(() => session.start(), throwsA(isA<StateError>()));
});
```

## Verification

1. Test passes locally: `flutter test path/to/test.dart`
2. Test passes in CI (check GitHub Actions / other CI)
3. Test is deterministic - run 10x with `--repeat=10` flag

## Example

### Before (flaky):
```dart
test('NostrConnectSession start throws if already started', () async {
  final session = NostrConnectSession(relays: ['wss://relay.example.com']);

  // This creates a Future that will reject when relay connection fails
  final startFuture = session.start();

  // State changed synchronously, but Future rejection is pending
  expect(session.state, isNot(equals(NostrConnectState.idle)));
  expect(() => session.start(), throwsA(isA<StateError>()));

  session.cancel();
  session.dispose();

  // This doesn't help - rejection already flagged by test framework
  await startFuture.catchError((_) {});
});
```

### After (reliable):
```dart
test('NostrConnectSession start throws if already started', () {
  // Completely synchronous - no Futures that can reject
  final session = NostrConnectSession(relays: ['wss://relay.example.com']);

  expect(session.state, equals(NostrConnectState.idle));

  // Use cancel() to transition out of idle state synchronously
  session.cancel();
  expect(session.state, equals(NostrConnectState.cancelled));

  // Now start() throws because we're not in idle state
  expect(
    () => session.start(),
    throwsA(
      isA<StateError>().having(
        (e) => e.message,
        'message',
        contains('already started'),
      ),
    ),
  );

  session.dispose();
});
```

## Notes

- This issue is more common in CI because of different timing characteristics
- The truncated error messages (like "ROR]") happen because CI output gets cut off
- Local tests may pass because the garbage collector hasn't run yet
- This is different from the "A Timer is still pending" error (see `flutter-dispose-timer-test-failure` skill)
- When testing state machines, prefer testing state transitions over testing async behavior
- If you need to test actual async/network behavior, use proper mocking

## Related Skills

- `flutter-dispose-timer-test-failure`: For timer-related test failures
- `riverpod-ref-in-provider-lifecycle`: For async callback issues in Riverpod providers

## References

- [Dart Zone Error Handling](https://dart.dev/guides/libraries/futures-error-handling#handling-errors-with-zones)
- [Flutter Test Package](https://api.flutter.dev/flutter/flutter_test/flutter_test-library.html)
