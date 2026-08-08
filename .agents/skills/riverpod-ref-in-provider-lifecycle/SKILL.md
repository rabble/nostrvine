---
name: riverpod-ref-in-provider-lifecycle
description: |
  Fix Riverpod "Cannot use Ref or modify other providers inside life-cycles/selectors" crash
  in @riverpod provider bodies. Use when: (1) Crash during provider disposal with this exact
  error message, (2) Using keepAlive() with timer-based disposal, (3) Async callbacks (.then,
  .catchError) try to use ref.read() or ref.invalidateSelf(), (4) Error occurs after
  ref.onCancel/onResume/onDispose callbacks fire. Solution: wrap ref operations in try-catch
  or avoid using ref in async callbacks entirely.
author: Claude Code
version: 1.0.0
date: 2026-02-01
---

# Riverpod ref Usage in Provider Lifecycle Callbacks

## Problem
When using `ref.keepAlive()` with timer-based auto-disposal in `@riverpod` providers,
async callbacks (`.then()`, `.catchError()`) that execute during or after disposal
will crash when they try to use `ref.read()`, `ref.invalidateSelf()`, or any other
ref operation.

## Context / Trigger Conditions

**Error message:**
```
'package:riverpod/src/core/ref.dart': Failed assertion: line 216 pos 7:
'_debugCallbackStack == 0': Cannot use Ref or modify other providers inside life-cycles/selectors.
```

**Typical scenario:**
1. Provider uses `ref.keepAlive()` with a timer in `ref.onCancel()`:
```dart
final link = ref.keepAlive();
ref.onCancel(() {
  Timer(Duration(seconds: 15), () {
    link.close();  // Triggers disposal
  });
});
```

2. Provider has async callbacks that use `ref`:
```dart
someAsyncOperation().then((_) {
  if (ref.mounted) {  // THIS CHECK IS NOT ENOUGH!
    ref.invalidateSelf();
  }
});
```

3. Timer fires while async callback is pending
4. CRASH - `ref.mounted` returns `true` but using `ref` is still forbidden

**Key insight:** `ref.mounted` returns `true` during lifecycle callbacks, but
using `ref` operations is still forbidden. This is counter-intuitive but by design.

## Solution

### Option 1: Wrap ref operations in try-catch (Recommended)

```dart
someAsyncOperation().then((_) {
  try {
    ref.read(someProvider.notifier).update(/*...*/);
  } catch (e) {
    Log.debug('Provider likely disposed: $e');
  }
});
```

### Option 2: Avoid ref operations in async callbacks entirely

Instead of:
```dart
// BAD - uses ref in async callback
openVineVideoCache.removeCorruptedVideo(videoId).then((_) {
  if (ref.mounted) {
    ref.invalidateSelf();  // CRASH!
  }
});
```

Do:
```dart
// GOOD - fire-and-forget without ref
unawaited(
  openVineVideoCache.removeCorruptedVideo(videoId).then((_) {
    Log.info('Cache removed');  // No ref usage
  }),
);
// Let user retry manually or provider recreates on next access
```

### Option 3: Capture provider state synchronously first

```dart
// Read state BEFORE async operation
final notifier = ref.read(someProvider.notifier);

// Use captured reference in callback (not ref)
someAsyncOperation().then((_) {
  notifier.doSomething();  // Uses captured reference, not ref
});
```

## Anti-Pattern: ref.mounted Check

```dart
// THIS DOES NOT WORK!
someAsyncOperation().then((_) {
  if (ref.mounted) {  // Returns true during lifecycle!
    ref.invalidateSelf();  // Still crashes!
  }
});
```

The `ref.mounted` check is insufficient because:
1. Timer fires, `link.close()` called
2. Riverpod enters disposal lifecycle (callback stack > 0)
3. `ref.mounted` check passes (still returns `true`!)
4. `ref.invalidateSelf()` called
5. CRASH - ref operations forbidden during lifecycle callbacks

## Verification

1. Rapidly scroll through content that uses the provider
2. Navigate away and back while providers are active
3. Let the keepAlive timers fire naturally (wait 15+ seconds after scrolling)
4. Check Crashlytics/console for the lifecycle assertion error
5. Error should no longer occur

## Example

### Before (causes crash):

```dart
@riverpod
VideoPlayerController videoController(Ref ref, String videoId) {
  final link = ref.keepAlive();

  ref.onCancel(() {
    Timer(Duration(seconds: 15), () => link.close());
  });

  final controller = VideoPlayerController.networkUrl(url);

  controller.initialize().catchError((error) {
    // CRASH! This callback may run during disposal
    if (ref.mounted) {
      ref.invalidateSelf();  // Assertion failure!
    }
  });

  return controller;
}
```

### After (safe):

```dart
@riverpod
VideoPlayerController videoController(Ref ref, String videoId) {
  final link = ref.keepAlive();

  ref.onCancel(() {
    Timer(Duration(seconds: 15), () => link.close());
  });

  final controller = VideoPlayerController.networkUrl(url);

  controller.initialize().catchError((error) {
    // Safe - wrapped in try-catch
    try {
      ref.read(fallbackProvider.notifier).state = newValue;
    } catch (e) {
      Log.debug('Provider disposed during error handling: $e');
    }
    // Don't invalidateSelf - let provider recreate on next access
  });

  return controller;
}
```

## Notes

- This issue is specific to `@riverpod` provider bodies, not widget dispose()
- The related skill `riverpod-ref-read-in-dispose` covers widget lifecycle issues
- Consider whether `ref.invalidateSelf()` is even necessary - often the provider
  will be recreated naturally on next access
- For truly critical cleanup, use `ref.onDispose()` which runs synchronously
  before the lifecycle callback stack check
- This bug is particularly common with video players, image loaders, and other
  resources that use keepAlive() with timer-based disposal

## Related Skills

- `riverpod-ref-read-in-dispose`: For widget dispose() ref.read() issues
- `flutter-dispose-timer-test-failure`: For timer-related test failures

## References

- [Riverpod ref.keepAlive](https://riverpod.dev/docs/concepts/modifiers/auto_dispose#refkeepalive)
- [Riverpod lifecycle callbacks](https://riverpod.dev/docs/concepts/provider_lifecycles)
