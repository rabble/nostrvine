// ABOUTME: BuildContext.safePop — pop with a guaranteed fallback target.
// ABOUTME: Use from AppBar back buttons reachable via go/goNamed/deep links.

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';

/// The route [safePop] navigates to when the back stack is empty and the
/// caller did not supply a `fallback`. Exposed so tests can assert against
/// the exact landing target instead of inferring it.
@visibleForTesting
final String defaultSafePopFallback = VideoFeedPage.pathForIndex(0);

/// Adds [safePop] to [BuildContext] for crash-safe back navigation.
extension SafePopExtension on BuildContext {
  /// Pops the current route if possible, otherwise navigates to [fallback].
  ///
  /// Plain `context.pop()` throws `GoError: There is nothing to pop` when
  /// the matched route hierarchy has nothing to pop back to — typically
  /// because the screen was reached via `go` / `goNamed` (which resets to
  /// the matched hierarchy and, for top-level routes, leaves a one-entry
  /// stack), or via a deep link / push notification. Calling [safePop]
  /// from AppBar back buttons and similar affordances degrades gracefully
  /// to [fallback] (or [defaultSafePopFallback] when omitted) instead of
  /// crashing.
  void safePop({String? fallback}) {
    if (canPop()) {
      pop();
    } else {
      go(fallback ?? defaultSafePopFallback);
    }
  }
}
