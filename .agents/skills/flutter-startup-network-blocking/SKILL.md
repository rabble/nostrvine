---
name: flutter-startup-network-blocking
description: |
  Fix slow Flutter app startup caused by blocking network operations during initialization.
  Use when: (1) App takes several seconds to show first frame, (2) Startup logs show sequential
  network operations (WebSocket connections, API calls), (3) Services initialize during startup
  that aren't needed until user authenticates. Covers: converting sequential network ops to
  parallel with Future.wait(), deferring service initialization until actually needed (lazy init),
  and identifying blocking operations in Riverpod/provider initialization chains.
author: Claude Code
version: 1.0.0
date: 2026-02-01
---

# Flutter Startup Network Blocking

## Problem
Flutter app startup is slow because network operations (WebSocket connections, API calls,
service initialization) run sequentially during the initialization phase, blocking the
first frame from rendering. With multiple relay/server connections, worst-case startup
time becomes O(n × timeout) instead of O(max timeout).

## Context / Trigger Conditions
- App takes 3+ seconds to show first frame on fresh launch
- Startup logs show sequential "connecting to relay X... connecting to relay Y..."
- Services that require authentication initialize even for unauthenticated users
- `_initializeCoreServices()` or similar contains multiple awaited network operations
- Riverpod providers eagerly initialize network-dependent services in their `build()` method

## Solution

### 1. Identify Blocking Operations
Look for sequential awaits in startup code:
```dart
// BAD: Sequential - each connection blocks the next
for (final url in relays) {
  await connectToRelay(url);  // Blocks startup!
}
```

### 2. Convert Sequential to Parallel
Use `Future.wait()` to run all connections simultaneously:
```dart
// GOOD: Parallel - all connections run at once
final results = await Future.wait(
  relays.map((url) async {
    final success = await connectToRelay(url);
    return MapEntry(url, success);
  }),
);
```

### 3. Defer Non-Critical Service Initialization
Move network-dependent services out of the critical startup path:

**Before (blocking startup):**
```dart
Future<void> _initializeCoreServices(ProviderContainer container) async {
  await container.read(authServiceProvider).initialize();
  await container.read(nostrServiceProvider).initialize();  // BLOCKS for relay connections!
  await container.read(otherServiceProvider).initialize();
}
```

**After (lazy initialization):**
```dart
Future<void> _initializeCoreServices(ProviderContainer container) async {
  // NOTE: NostrService initializes lazily when user authenticates
  await container.read(authServiceProvider).initialize();
  await container.read(seenVideosServiceProvider).initialize();
  // NostrService NOT initialized here - happens when auth state changes
}
```

### 4. Use Provider Dependencies for Lazy Init
Let Riverpod handle lazy initialization through provider dependencies:
```dart
@riverpod
NostrClient nostrClient(NostrClientRef ref) {
  final authService = ref.watch(authServiceProvider);

  // Only creates client when auth state is ready
  if (!authService.isAuthenticated) {
    return NostrClient.disconnected();
  }

  // Initialize lazily when actually needed
  final client = NostrClient(relays: authService.userRelays);
  Future.microtask(() => client.initialize());
  return client;
}
```

## Verification
1. Check startup logs for "First frame rendered in Xms" - should be < 2000ms
2. Verify network operations happen AFTER first frame timestamp in logs
3. For unauthenticated users, relay connections should NOT appear in startup logs

## Example

**Startup improvement achieved:**
- Before: First frame at 3500ms+ (waiting for 5 relays × ~700ms each)
- After: First frame at 1426ms (parallel connections happen post-frame)

**Log pattern showing fix working:**
```
[18:15:17.538] First frame rendered in 1426ms
[18:15:17.556] Creating NostrClient...  // AFTER first frame!
```

## Notes
- This pattern applies to any async initialization, not just WebSockets
- Consider timeout handling when parallelizing - use `Future.wait` with error handling
- For critical services, use a loading screen rather than blocking the main thread
- Profile with Flutter DevTools Timeline to identify other startup bottlenecks
- Remember that `Future.wait()` fails fast by default - use try/catch inside the map if you want partial success

## Related Patterns
- Splash screen with async initialization
- Riverpod `AsyncNotifier` for lazy-loaded state
- Background service initialization after first frame

## References
- [Flutter Performance Best Practices](https://docs.flutter.dev/perf/best-practices)
- [Dart Future.wait documentation](https://api.dart.dev/stable/dart-async/Future/wait.html)
- [Riverpod lazy initialization](https://riverpod.dev/docs/concepts/providers#lazy-initialization)
