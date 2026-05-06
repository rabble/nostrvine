---
name: flutter-deactivate-setstate-during-build
description: |
  Fix "setState() or markNeedsBuild() called during build" error triggered from deactivate().
  Use when: (1) Error occurs during widget disposal or navigation away, (2) Stack trace shows
  deactivate -> some notifier -> ValueListenableBuilder._valueChanged, (3) Video/audio player
  pause() or stop() calls in deactivate() cause the error. The fix is deferring state-modifying
  operations to addPostFrameCallback.
author: Claude Code
version: 1.0.0
date: 2025-01-27
---

# Flutter: setState During Build from deactivate()

## Problem
When navigating away from a screen, calling methods like `VideoPlayerController.pause()` in
`deactivate()` triggers `setState() or markNeedsBuild() called during build` because the
controller notifies its listeners synchronously during widget tree teardown.

## Context / Trigger Conditions
- Error: `setState() or markNeedsBuild() called during build`
- Stack trace includes:
  - `YourWidget.deactivate`
  - `VideoPlayerController.pause` (or similar)
  - `ChangeNotifier.notifyListeners`
  - `ValueListenableBuilder._valueChanged`
- Widget using `ValueListenableBuilder<VideoPlayerValue>` or similar
- Trying to pause/stop media playback when navigating away

## Solution
Defer the state-modifying operation to after the current frame:

```dart
@override
void deactivate() {
  // Capture controller reference while ref/context is still valid
  final controller = _getController();

  // Defer pause to after current frame
  if (controller != null && controller.value.isPlaying) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.value.isPlaying) {
        controller.pause();
      }
    });
  }

  super.deactivate();
}
```

## Key Insights

1. **Why deactivate() is problematic**: It's called during the widget tree teardown phase,
   which is part of the build process. Any synchronous notification to listeners will
   trigger rebuilds during build.

2. **Why dispose() doesn't have this issue**: By `dispose()`, the widget is fully unmounted
   and listeners are typically already removed.

3. **Capture references early**: Get controller/state references before the async gap
   since `ref`, `context`, or other widget state may become invalid.

4. **Guard against double-execution**: Check `isPlaying` again in the callback since
   state may have changed.

## Verification
- Navigate away from the screen multiple times
- No error in console
- Video/audio properly pauses when leaving

## Example: Full Implementation

```dart
class _FullscreenVideoScreenState extends ConsumerState<FullscreenVideoScreen> {
  @override
  void deactivate() {
    _schedulePauseCurrentVideo();
    super.deactivate();
  }

  void _schedulePauseCurrentVideo() {
    final controller = _getCurrentController();
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    // Defer to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.value.isPlaying) {
        controller.pause();
      }
    });
  }
}
```

## Notes
- This pattern applies to any `ChangeNotifier` that updates synchronously
- Also relevant for: `AnimationController.stop()`, `TextEditingController` updates
- If you need the pause to happen immediately (rare), consider using
  `controller.pause()` without notifying, though this breaks the observer pattern
- The same issue can occur in `didUpdateWidget` when old controllers are disposed

## Related Patterns
- Use `deactivate()` for cleanup that needs `ref`/`context` (like unsubscribing)
- Use `dispose()` for cleanup that doesn't (like disposing controllers you own)
- Never call `setState()` in `deactivate()` or `dispose()`
