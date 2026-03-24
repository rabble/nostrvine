Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# Future.delayed Migration Guide

## Overview

This guide documents how to replace all `Future.delayed` usages with proper async patterns in the OpenVine codebase. The analyzer is configured to treat `Future.delayed` as an error via the `avoid_future_delayed` lint rule.

## Common Patterns and Replacements

### 1. Waiting for Initialization

**❌ OLD PATTERN:**
```dart
await Future.delayed(const Duration(seconds: 3)); // Wait for connection
```

**✅ NEW PATTERN:**
```dart
// Use AsyncUtils.waitForCondition
await AsyncUtils.waitForCondition(
  condition: () => isConnected,
  timeout: const Duration(seconds: 5),
  debugName: 'connection-complete',
);

// Or use event-based completion
final completer = Completer<void>();
onConnectionComplete = () => completer.complete();
await completer.future.timeout(const Duration(seconds: 5));
```

### 2. Animation Completion

**❌ OLD PATTERN:**
```dart
scrollController.animateTo(0, duration: Duration(milliseconds: 500));
Future.delayed(Duration(milliseconds: 600), () {
  _handleRefresh();
});
```

**✅ NEW PATTERN:**
```dart
// Chain to animation future
await scrollController.animateTo(
  0,
  duration: const Duration(milliseconds: 500),
  curve: Curves.easeOutCubic,
);
_handleRefresh(); // Executes after animation completes
```

### 3. Retry Logic

**❌ OLD PATTERN:**
```dart
for (int i = 0; i < maxRetries; i++) {
  try {
    return await operation();
  } catch (e) {
    if (i < maxRetries - 1) {
      await Future.delayed(Duration(seconds: 2 * (i + 1)));
    }
  }
}
```

**✅ NEW PATTERN:**
```dart
return await AsyncUtils.retryWithBackoff(
  operation: () => operation(),
  maxRetries: 3,
  baseDelay: const Duration(seconds: 2),
  backoffMultiplier: 2.0,
  debugName: 'network-operation',
);
```

### 4. Debouncing User Input

**❌ OLD PATTERN:**
```dart
Timer? _debounceTimer;
void _onSearchChanged(String query) {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(Duration(milliseconds: 500), () {
    _performSearch(query);
  });
}
```

**✅ NEW PATTERN:**
```dart
final _debouncedSearch = AsyncUtils.debounce(
  operation: () => _performSearch(_currentQuery),
  delay: const Duration(milliseconds: 500),
);

void _onSearchChanged(String query) {
  _currentQuery = query;
  _debouncedSearch();
}
```

### 5. Polling for State Changes

**❌ OLD PATTERN:**
```dart
while (!isReady && attempts < 50) {
  await Future.delayed(Duration(milliseconds: 100));
  attempts++;
}
```

**✅ NEW PATTERN:**
```dart
final ready = await AsyncUtils.waitForCondition(
  condition: () => isReady,
  timeout: const Duration(seconds: 5),
  checkInterval: const Duration(milliseconds: 100),
  debugName: 'state-ready',
);
```

### 6. WebSocket Reconnection

**❌ OLD PATTERN:**
```dart
void _reconnect() async {
  await Future.delayed(Duration(seconds: _retryDelay));
  _retryDelay = min(_retryDelay * 2, 60);
  _connect();
}
```

**✅ NEW PATTERN:**
```dart
void _reconnect() {
  Timer(Duration(seconds: _retryDelay), () {
    _retryDelay = min(_retryDelay * 2, 60);
    _connect();
  });
}

// Or use AsyncUtils for more control
await AsyncUtils.retryWithBackoff(
  operation: () => _connect(),
  maxRetries: 5,
  baseDelay: const Duration(seconds: 1),
  maxDelay: const Duration(minutes: 1),
  retryWhen: (error) => error is SocketException,
);
```

### 7. Stream-based State Waiting

**❌ OLD PATTERN:**
```dart
// Wait for stream to emit specific value
while (true) {
  if (_stateStream.value == TargetState.ready) break;
  await Future.delayed(Duration(milliseconds: 50));
}
```

**✅ NEW PATTERN:**
```dart
await AsyncUtils.waitForStreamValue(
  stream: _stateStream,
  predicate: (state) => state == TargetState.ready,
  timeout: const Duration(seconds: 10),
  debugName: 'target-state',
);
```

### 8. Test Timing

**❌ OLD PATTERN:**
```dart
test('should complete after delay', () async {
  startOperation();
  await Future.delayed(Duration(seconds: 1));
  expect(isComplete, true);
});
```

**✅ NEW PATTERN:**
```dart
test('should complete after operation', () async {
  final completer = Completer<void>();
  startOperation(onComplete: completer.complete);
  await completer.future.timeout(const Duration(seconds: 1));
  expect(isComplete, true);
});
```

## AsyncUtils API Reference

### Core Methods

1. **waitForCondition** - Wait for a condition to become true
2. **retryWithBackoff** - Retry with exponential backoff
3. **waitForStreamValue** - Wait for stream to emit matching value
4. **debounce** - Debounce rapid calls
5. **throttle** - Throttle call frequency
6. **createCompletionHandler** - Create external completer

### AsyncInitialization Mixin

For classes that need proper initialization patterns:

```dart
class MyService with AsyncInitialization {
  Future<void> initialize() async {
    startInitialization();
    
    try {
      await _connect();
      await _authenticate();
      completeInitialization();
    } catch (e) {
      failInitialization(e);
      rethrow;
    }
  }
}

// Usage
final service = MyService();
await service.initialize();
await service.waitForInitialization(timeout: Duration(seconds: 10));
```

## Migration Checklist

- [ ] Run `grep -r "Future\.delayed" lib/` to find all occurrences
- [ ] Replace each occurrence with appropriate AsyncUtils method
- [ ] Update tests to use proper async patterns
- [ ] Run `flutter analyze` to ensure no Future.delayed remains
- [ ] Run all tests to verify functionality

## Benefits

1. **Predictable Timing** - Based on actual events, not arbitrary delays
2. **Better Testing** - Can control timing in tests
3. **Performance** - No unnecessary waiting
4. **Debugging** - Clear intent and better error messages
5. **Maintainability** - Consistent patterns across codebase