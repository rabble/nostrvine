---
name: flutter-dispose-timer-test-failure
description: |
  Fix Flutter test failure "A Timer is still pending even after the widget tree was disposed".
  Use when: (1) Widget tests fail with timer pending error, (2) dispose() contains Future(),
  Future.delayed(), or Timer calls, (3) Riverpod provider modifications in dispose().
  The fix is to use deactivate() instead of dispose() for cleanup that might trigger async work.
author: Claude Code
version: 1.0.0
date: 2025-01-26
---

# Flutter Dispose Timer Test Failure

## Problem
Flutter widget tests fail with the error "A Timer is still pending even after the widget
tree was disposed" when dispose() contains Future-based cleanup code.

## Context / Trigger Conditions
- Test error: `A Timer is still pending even after the widget tree was disposed`
- Widget's `dispose()` method contains:
  - `Future(() => ...)`
  - `Future.delayed(...)`
  - `Timer(...)` or `Timer.periodic(...)`
  - Riverpod `ref.read(provider.notifier).someMethod()` wrapped in Future
- Tests pass individually but fail when run together
- Error appears at end of test, not during widget interaction

## Solution

### Step 1: Identify the problematic code
Look for patterns like this in your widget:

```dart
// BAD: Creates pending timer that test framework detects
@override
void dispose() {
  final notifier = _overlayNotifier;
  if (notifier != null) {
    Future(() => notifier.setSettingsOpen(false));  // <- Problem!
  }
  super.dispose();
}
```

### Step 2: Move cleanup to deactivate()
Use `deactivate()` instead of `dispose()` and remove the Future wrapper:

```dart
// GOOD: Runs synchronously before widget is removed
@override
void deactivate() {
  _overlayNotifier?.setSettingsOpen(false);  // Direct call, no Future
  super.deactivate();
}
```

### Step 3: Understand the lifecycle difference
- `deactivate()`: Called when widget is removed from tree, but State might be reinserted
- `dispose()`: Called when State will never build again, permanent cleanup

For most notification/provider cleanup, `deactivate()` is appropriate.

## Verification
1. Run the specific test that was failing
2. Run the full test suite
3. Verify no "Timer is still pending" errors

## Example

### Before (causes test failure):
```dart
class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  OverlayNotifier? _overlayNotifier;

  @override
  void dispose() {
    final notifier = _overlayNotifier;
    if (notifier != null) {
      // This Future creates a pending timer!
      Future(() => notifier.setSettingsOpen(false));
    }
    super.dispose();
  }
}
```

### After (tests pass):
```dart
class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  OverlayNotifier? _overlayNotifier;

  @override
  void deactivate() {
    // Synchronous call, no timer created
    _overlayNotifier?.setSettingsOpen(false);
    super.deactivate();
  }
}
```

## Notes
- The original `Future(() => ...)` pattern is often used to defer provider modifications
  until after the current build phase, avoiding "Cannot modify provider during build" errors
- If you need deferred execution, consider `WidgetsBinding.instance.addPostFrameCallback`
  instead, though this also creates timers that can fail tests
- For Riverpod, modifying providers in `deactivate()` is usually safe since the widget
  tree is being torn down, not built
- This issue often surfaces when multiple tests run sequentially, as the test framework
  checks for pending timers between tests

## References
- [Flutter Widget Lifecycle](https://api.flutter.dev/flutter/widgets/State-class.html)
- [Flutter Testing: Pending Timers](https://docs.flutter.dev/testing/overview)
