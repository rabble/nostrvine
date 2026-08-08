---
name: riverpod-ref-read-in-dispose
description: |
  Fix Riverpod "Using ref when widget is unmounted is unsafe" error in ConsumerStatefulWidget.
  Use when: (1) Error thrown in dispose() when calling ref.read(), (2) Need to call a service
  method during widget cleanup, (3) ConsumerStatefulWidget needs to perform actions on provider
  when user navigates away. Solution: cache the service/notifier in initState with late final.
author: Claude Code
version: 1.0.0
date: 2026-02-01
---

# Riverpod ref.read() in dispose() Error

## Problem
When a `ConsumerStatefulWidget` needs to call a service method in `dispose()` (e.g., to cancel
an operation when the user leaves a screen), using `ref.read()` throws an error because the
widget is already unmounted.

## Context / Trigger Conditions
- Error message: `Using ref when widget is unmounted is unsafe`
- Using `ConsumerStatefulWidget` with `ConsumerState`
- Calling `ref.read(someProvider)` inside `dispose()`
- Widget navigates away (pop, push replacement, etc.)
- Stack trace shows the error originating from dispose()

Example problematic code:
```dart
@override
void dispose() {
  ref.read(authServiceProvider).cancelOperation();  // ERROR!
  super.dispose();
}
```

## Solution

### Step 1: Add a late final field for the service
```dart
class _MyScreenState extends ConsumerState<MyScreen> {
  late final MyService _myService;  // Cache here
```

### Step 2: Initialize in initState
```dart
@override
void initState() {
  super.initState();
  _myService = ref.read(myServiceProvider);  // Safe here
}
```

### Step 3: Use cached reference in dispose
```dart
@override
void dispose() {
  _myService.cancelOperation();  // Use cached reference
  super.dispose();
}
```

## Verification
1. Navigate to the screen
2. Navigate away (back button, push replacement, etc.)
3. No "Using ref when widget is unmounted" error in console
4. The cleanup action (cancel, close, etc.) still executes

## Example

### Before (causes error):
```dart
class _NostrConnectScreenState extends ConsumerState<NostrConnectScreen> {
  @override
  void dispose() {
    // ERROR: ref is not safe to use here
    ref.read(authServiceProvider).cancelNostrConnect();
    super.dispose();
  }
}
```

### After (works correctly):
```dart
class _NostrConnectScreenState extends ConsumerState<NostrConnectScreen> {
  // Cache AuthService for use in dispose (can't use ref.read in dispose)
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = ref.read(authServiceProvider);
  }

  @override
  void dispose() {
    // Cancel the session if user leaves the screen
    _authService.cancelNostrConnect();
    super.dispose();
  }
}
```

## Notes
- This pattern is necessary because Riverpod's `ref` is tied to the widget lifecycle
- `ref.read()` is safe in `initState()` because the widget is being mounted
- `ref.read()` is NOT safe in `dispose()` because the widget is being unmounted
- The `late final` pattern ensures the service is initialized exactly once
- This applies to any cleanup that requires calling methods on providers
- For simple provider state changes (not method calls), consider using `deactivate()` instead
- If the service itself might be disposed, add null checks or try-catch as appropriate

## Related Skills
- `flutter-dispose-timer-test-failure`: For timer-related dispose issues
- `flutter-deactivate-setstate-during-build`: For setState/build cycle issues in deactivate

## References
- [Riverpod ConsumerStatefulWidget](https://riverpod.dev/docs/concepts/reading#using-refread-to-obtain-the-state-of-a-provider)
- [Flutter State.dispose](https://api.flutter.dev/flutter/widgets/State/dispose.html)
