// ABOUTME: State extension that schedules a post-frame callback guarded by the
// ABOUTME: widget's mounted flag, so async/post-frame UI work never outlives it.

import 'package:flutter/widgets.dart';

/// Lifecycle-safe [addPostFrameCallback] for a [State].
extension MountedPostFrame on State {
  /// Runs [callback] after the next frame, but only if this [State] is still
  /// mounted when that frame lands.
  ///
  /// A post-frame callback scheduled from a [State] still fires after the
  /// widget has been disposed. If the callback then reads `context` or touches
  /// a provider it crashes ("looking up a deactivated widget's ancestor" /
  /// `State.context` used after unmount) — a class of non-fatal Crashlytics
  /// reports for editor UI whose post-frame work raced the screen teardown.
  /// Routing that work through this guard drops it when the widget is gone.
  ///
  /// [callback] may be `async`; like a raw post-frame callback its future is
  /// fire-and-forget, so any work after an `await` inside it must re-check
  /// [mounted] before touching `context` again.
  void addPostFrameCallbackIfMounted(VoidCallback callback) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      callback();
    });
  }
}
