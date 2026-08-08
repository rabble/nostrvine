---
name: async-await-null-race-condition
description: |
  Fix "Null check operator used on a null value" errors when an object is set to null
  during an async await. Use when: (1) Object reference is nullified while awaiting,
  (2) Code accesses object with ! after await returns, (3) Cancel/dispose operations
  run concurrently with async operations on same object. Solution: capture local
  reference before await.
author: Claude Code
version: 1.0.0
date: 2026-02-01
---

# Async Await Null Race Condition

## Problem
When an async operation is awaiting, external code can set the object reference to null.
When the await completes, accessing the object with `!` throws "Null check operator
used on a null value".

## Context / Trigger Conditions
- Error: `Null check operator used on a null value`
- Pattern: `await someObject!.asyncMethod()` followed by `someObject!.property`
- Object can be nullified by cancel/dispose/cleanup operations
- Concurrent operations on shared mutable state
- Typically seen with session objects, connection handlers, or service references

## Solution

### Wrong - Object can become null during await:
```dart
Future<Result> waitForResponse() async {
  // _session might be set to null while we're awaiting
  final result = await _session!.waitForConnection();

  if (result == null) {
    // BUG: _session could be null here!
    final state = _session!.state;  // Throws null check error
    ...
  }
}

void cancel() {
  _session?.cancel();
  _session = null;  // This runs while waitForResponse is awaiting
}
```

### Correct - Capture local reference before await:
```dart
Future<Result> waitForResponse() async {
  // Capture reference BEFORE await
  final session = _session!;

  final result = await session.waitForConnection();

  // Check if cancelled during await
  if (_session == null) {
    return Result.cancelled();
  }

  if (result == null) {
    // Safe - using captured local reference
    final state = session.state;
    ...
  }
}
```

## Verification
1. Trigger the cancel/dispose operation while async operation is in progress
2. No null check errors should occur
3. Operation should gracefully handle cancellation

## Example - Full Pattern

```dart
class ConnectionManager {
  Session? _session;

  Future<ConnectionResult> connect() async {
    if (_session == null) {
      return ConnectionResult.failure('No session');
    }

    // Capture before await
    final session = _session!;

    final response = await session.waitForResponse(
      timeout: Duration(minutes: 2),
    );

    // Check if cancelled during await
    if (_session == null) {
      return ConnectionResult.failure('Cancelled');
    }

    // Safe to use captured reference
    if (response == null) {
      return ConnectionResult.failure(session.errorMessage);
    }

    return ConnectionResult.success(response);
  }

  void cancel() {
    _session?.cancel();
    _session?.dispose();
    _session = null;
  }
}
```

## Notes
- This pattern applies to any mutable reference that can be nullified externally
- Common in Flutter/Dart with dispose patterns, Riverpod providers, and WebSocket sessions
- The captured local reference keeps the object alive during the await
- Always add a null check after await to detect cancellation
- Consider using `Completer` cancellation patterns for more complex scenarios

## Related Patterns
- `riverpod-ref-read-in-dispose` - Similar issue with Riverpod ref lifecycle
- `flutter-dispose-timer-test-failure` - Timer callbacks after disposal
