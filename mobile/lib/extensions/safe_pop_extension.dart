// ABOUTME: BuildContext.safePop — pop with a guaranteed fallback target.
// ABOUTME: Use from AppBar back buttons reachable via go/goNamed/deep links.

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Default fallback when there is nothing to pop. The home feed root is
/// always present in the route tree, so it is always safe to land on.
const String _defaultSafePopFallback = '/home/0';

/// Adds [safePop] to [BuildContext] for crash-safe back navigation.
extension SafePopExtension on BuildContext {
  /// Pops the current route if possible, otherwise navigates to [fallback].
  ///
  /// Plain `context.pop()` throws `GoError: There is nothing to pop` when
  /// the current route is the only one in the stack — which happens
  /// whenever the screen was reached via `go` / `goNamed` (both replace
  /// the stack) or via a deep link / push notification. Calling [safePop]
  /// from AppBar back buttons and similar affordances degrades gracefully
  /// to [fallback] instead of crashing.
  void safePop({String fallback = _defaultSafePopFallback}) {
    if (canPop()) {
      pop();
    } else {
      go(fallback);
    }
  }
}
