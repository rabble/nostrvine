// ABOUTME: Shared CustomTransitionPage with the classic fade-upwards
// ABOUTME: transition (pre-Pie Android) for modal creation/library flows

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Wraps [child] in a page that fades in while sliding up the last
/// quarter — the classic pre-Pie Android transition.
///
/// Mirrors go_router's default page metadata (`name`, `arguments`,
/// `restorationId`) from [state] so root-navigator observers such as
/// `PageLoadObserver` keep resolving a real route name instead of
/// `unknown_route`. Call it from a route's `pageBuilder`.
CustomTransitionPage<void> fadeUpwardsPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    name: state.name ?? state.path,
    arguments: <String, String>{
      ...state.pathParameters,
      ...state.uri.queryParameters,
    },
    restorationId: state.pageKey.value,
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
