// ABOUTME: Shared CustomTransitionPage with the classic fade-upwards
// ABOUTME: transition (pre-Pie Android) for modal creation/library flows

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Wraps [child] in a page that fades in while sliding up the last
/// quarter — the classic pre-Pie Android transition.
///
/// Pass `state.pageKey` from the route's `pageBuilder` as [key].
CustomTransitionPage<void> fadeUpwardsPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        const FadeUpwardsPageTransitionsBuilder().buildTransitions<void>(
          null,
          context,
          animation,
          secondaryAnimation,
          child,
        ),
  );
}
