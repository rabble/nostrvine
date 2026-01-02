// ABOUTME: Route transition page classes for consistent page animations
// ABOUTME: Provides Page subclasses for standard, slide-in, and modal transitions

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Standard MaterialPage for default screen navigation.
class StandardPage<T> extends MaterialPage<T> {
  const StandardPage({
    required super.child,
    required LocalKey super.key,
    super.name,
    super.maintainState = true,
  });
}

/// Page with slide-in from right transition.
class SlideInPage<T> extends CustomTransitionPage<T> {
  SlideInPage({required super.child, required LocalKey super.key, super.name})
    : super(transitionsBuilder: _slideInTransition);

  static Widget _slideInTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
      child: child,
    );
  }
}

/// Page with slide-up from bottom transition (for modals).
class ModalPage<T> extends CustomTransitionPage<T> {
  ModalPage({
    required super.child,
    required LocalKey super.key,
    super.name,
    super.fullscreenDialog = true,
  }) : super(transitionsBuilder: _modalTransition);

  static Widget _modalTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
      child: child,
    );
  }
}
