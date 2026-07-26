// ABOUTME: A modal spinner route that is dismissed by route identity, not by popping.
// ABOUTME: Safe to use around awaits where other routes may appear or disappear.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// A blocking spinner pushed as its own route.
///
/// [dismiss] removes *this* route by identity rather than popping whatever
/// happens to be on top, so an unrelated dialog or a router redirect appearing
/// during the awaited work cannot be closed by mistake. It is also idempotent
/// and safe to call after the navigator is gone.
class ModalProgressOverlay {
  ModalProgressOverlay._(
    this._navigator, {
    required this.route,
    required this.closed,
  });

  final NavigatorState _navigator;
  final Route<void> route;
  final Future<void> closed;
  bool _dismissed = false;

  static ModalProgressOverlay show(BuildContext context) {
    final navigator = Navigator.of(context, rootNavigator: true);
    late final DialogRoute<void> route;
    route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      ),
    );

    final closed = navigator.push(route);
    return ModalProgressOverlay._(navigator, route: route, closed: closed);
  }

  void dismiss() {
    if (_dismissed || !_navigator.mounted || !route.isActive) return;
    _dismissed = true;
    _navigator.removeRoute(route);
  }
}
