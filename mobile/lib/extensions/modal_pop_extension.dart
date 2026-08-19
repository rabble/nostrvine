// ABOUTME: BuildContext.popModalIfMounted — pop a dialog or sheet from its own
// ABOUTME: callback context without walking a route that is already gone.

import 'package:flutter/widgets.dart';

/// Adds [popModalIfMounted] to [BuildContext] for dialog and sheet callbacks.
extension ModalPopExtension on BuildContext {
  /// Pops the modal route this context belongs to, unless it is already gone.
  ///
  /// A dialog or sheet callback closes over the context its builder was handed.
  /// That context's element is unmounted the moment the route is torn down, and
  /// a route can disappear while a tap is still in flight — a rebuild above the
  /// modal, a redirect, a deep link. `Navigator.of` then walks a defunct
  /// element and throws: `Looking up a deactivated widget's ancestor is unsafe`
  /// in debug, a `_state!` null check in release AOT. Either way the pop never
  /// happens and the tap silently does nothing, but `FlutterError.onError`
  /// files that no-op in Crashlytics as a fatal (#6512, #7291).
  ///
  /// Two separate things have to hold before popping, because `Navigator.pop`
  /// takes the navigator's *topmost* route rather than this context's own:
  ///
  /// 1. The context is still mounted. Otherwise `Navigator.of` throws as above.
  /// 2. This context's modal route is still the current one. A modal stays
  ///    mounted for the length of its exit transition, so a second tap that
  ///    lands in that window passes the mounted check and would pop whatever
  ///    is underneath — the screen the modal was covering.
  ///
  /// Skipping the pop is safe in both cases: the route is already closed or
  /// closing, so the pop was moot. Whatever awaited `showDialog` /
  /// `showModalBottomSheet` resolves off that teardown with `null`, and every
  /// confirmation call site here already reads `null` as "not confirmed".
  ///
  /// Returns whether the pop was attempted, so a callback that does more than
  /// pop can bail out of the rest for the same reason:
  ///
  /// ```dart
  /// onTap: () {
  ///   if (!sheetContext.popModalIfMounted()) return;
  ///   openEditor();
  /// },
  /// ```
  ///
  /// This is not `safePop` from `safe_pop_extension.dart`, which solves the
  /// opposite problem: a *live* context whose GoRouter back stack is empty, and
  /// which navigates to a fallback route rather than doing nothing. Reach for
  /// that one from AppBar back buttons; reach for this one from inside a modal.
  bool popModalIfMounted<T extends Object?>([T? result]) {
    if (!mounted) {
      return false;
    }
    if (ModalRoute.isCurrentOf(this) != true) {
      return false;
    }
    Navigator.of(this).pop<T>(result);
    return true;
  }
}
