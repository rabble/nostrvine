---
name: riverpod-ref-listen-build-only
description: |
  Fix "ref.listen can only be used within the build method of a ConsumerWidget" assertion
  error in Flutter Riverpod 3.x. Use when: (1) ConsumerStatefulWidget crashes with
  "Failed assertion: line 492 pos 7: 'debugDoingBuild'" in flutter_riverpod consumer.dart,
  (2) ref.listen is called inside initState, addPostFrameCallback, or any lifecycle method
  other than build(), (3) All widget tests fail with this assertion from scheduler callback.
  Applies to flutter_riverpod 3.0+ with ConsumerStatefulWidget.
author: Claude Code
version: 1.0.0
date: 2026-02-06
---

# Riverpod ref.listen Must Be in build() for ConsumerStatefulWidget

## Problem
In Riverpod 3.x, calling `ref.listen` inside `initState()`, `addPostFrameCallback`, or
any method other than `build()` causes an assertion failure:

```
ref.listen can only be used within the build method of a ConsumerWidget
'package:flutter_riverpod/src/core/consumer.dart':
Failed assertion: line 492 pos 7: 'debugDoingBuild'
```

This typically manifests when trying to reactively watch a provider value that may change
after the widget is first built (e.g., waiting for an async operation to complete).

## Context / Trigger Conditions
- Using `ConsumerStatefulWidget` with `flutter_riverpod: ^3.0.0`
- Calling `ref.listen(provider, callback)` inside `initState()` or a post-frame callback
- All widget tests fail with the assertion error from `ConsumerStatefulElement.listen`
- The error occurs during `pumpWidget` or `pumpAndSettle` in tests
- Stack trace shows `SchedulerBinding._invokeFrameCallback` -> `ConsumerStatefulElement.listen`

## Solution

Move `ref.listen` into the `build()` method. Use a guard flag to ensure side effects
only trigger once.

**Before (broken):**
```dart
class _MyScreenState extends ConsumerState<MyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // THIS WILL CRASH in Riverpod 3.x
      ref.listen(
        myProvider.select((s) => s.someValue),
        (previous, next) {
          if (previous == null && next != null) {
            _doSomething(next);
          }
        },
      );
    });
  }
}
```

**After (fixed):**
```dart
class _MyScreenState extends ConsumerState<MyScreen> {
  bool _actionAttempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Immediate check for already-available data
      final value = ref.read(myProvider).someValue;
      if (value != null) _tryDoSomething(value);
    });
  }

  void _tryDoSomething(SomeType? value) {
    if (value == null || _actionAttempted) return;
    _actionAttempted = true;
    _doSomething(value);
  }

  @override
  Widget build(BuildContext context) {
    // ref.listen is safe here - Riverpod auto-manages the subscription
    ref.listen(
      myProvider.select((s) => s.someValue),
      (previous, next) {
        if (previous == null && next != null) {
          _tryDoSomething(next);
        }
      },
    );

    return // ... widget tree
  }
}
```

### Key points:
1. `ref.listen` in `build()` is auto-managed by Riverpod (no manual disposal needed)
2. It re-registers each build but Riverpod handles deduplication
3. Use a guard flag (`_actionAttempted`) to prevent side effects from firing multiple times
4. Keep the immediate check in `initState`'s post-frame callback for when data is already available
5. `ref.read` is fine in `initState`/callbacks; only `ref.listen` and `ref.watch` are restricted

## Verification
- All widget tests pass without assertion errors
- The listener fires correctly when the watched value changes
- Side effects only trigger once (verify with a counter or log)

## Notes
- `ref.watch` is also restricted to `build()` only
- `ref.read` can be used anywhere (initState, callbacks, dispose, etc.)
- In older Riverpod versions (< 3.0), `ref.listen` was less restricted
- If you need a listener outside `build()`, use `ref.listenManual()` which returns
  a `ProviderSubscription` that must be manually disposed in `dispose()`
- This constraint exists because Riverpod needs the widget's element context to properly
  manage subscription lifecycle

## References
- https://riverpod.dev/docs/essentials/combining_requests
- https://pub.dev/packages/flutter_riverpod/changelog (3.0.0 breaking changes)
