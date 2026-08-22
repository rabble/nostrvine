// ABOUTME: Hosts the active ProviderContainer and swaps it in place on an
// ABOUTME: account switch — no widget-tree remount, no welcome-screen bounce.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Handle the UI uses to request an in-place container swap.
///
/// The switch trigger lives *above* the [ProviderContainer] (it must outlive
/// the container being replaced), so it can't be a provider inside the tree.
/// UI code holds this controller — surfaced via an inherited widget above the
/// scope, or the same instance injected into each container — and calls
/// [swapTo] with a freshly-built, already-signed-in container for the target
/// account.
class AccountSwitchController {
  Future<void> Function(
    ProviderContainer next,
    Future<void> Function()? beforePreviousContainerDispose,
  )?
  _onSwap;
  ProviderContainer? _currentContainer;
  bool _switchInProgress = false;

  /// Whether a [ContainerSwapHost] is mounted and ready to swap.
  bool get isReady => _onSwap != null;

  /// The currently mounted account container, when a host is active.
  ProviderContainer? get currentContainer => _currentContainer;

  /// Runs [body] while rejecting overlapping switch attempts.
  Future<T> runExclusive<T>(Future<T> Function() body) async {
    if (_switchInProgress) {
      throw StateError('Account switch already in progress');
    }
    _switchInProgress = true;
    try {
      return await body();
    } finally {
      _switchInProgress = false;
    }
  }

  /// Requests the host swap the live container to [next].
  ///
  /// [next] must already be built (via `buildAccountContainer`) and signed in
  /// as the target account — the host only mounts it and disposes the old one.
  Future<void> swapTo(
    ProviderContainer next, {
    Future<void> Function()? beforePreviousContainerDispose,
  }) {
    final onSwap = _onSwap;
    if (onSwap == null) {
      throw StateError('ContainerSwapHost is not mounted');
    }
    return onSwap(next, beforePreviousContainerDispose);
  }
}

/// Owns the active [ProviderContainer] and rebuilds the app under a new one
/// when the account switches, disposing the previous container after the frame.
///
/// Replaces the single `UncontrolledProviderScope` at the app root. The device
/// singletons ([DeviceScope]) are shared across containers, so only the leaving
/// account's account-scoped runtime is torn down.
class ContainerSwapHost extends StatefulWidget {
  const ContainerSwapHost({
    required this.initialContainer,
    required this.controller,
    required this.child,
    super.key,
  });

  /// The container the app boots with (the initial account, or signed-out).
  final ProviderContainer initialContainer;

  /// Controller the UI calls to trigger a swap.
  final AccountSwitchController controller;

  final Widget child;

  @override
  State<ContainerSwapHost> createState() => _ContainerSwapHostState();
}

class _ContainerSwapHostState extends State<ContainerSwapHost> {
  late ProviderContainer _container;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _container = widget.initialContainer;
    widget.controller._currentContainer = _container;
    widget.controller._onSwap = _swap;
  }

  Future<void> _swap(
    ProviderContainer next,
    Future<void> Function()? beforePreviousContainerDispose,
  ) async {
    if (!mounted) {
      // The host is gone; the caller owns the orphaned container.
      next.dispose();
      return;
    }
    if (identical(next, _container)) return;

    final previous = _container;
    setState(() {
      _container = next;
      _generation += 1;
      widget.controller._currentContainer = next;
    });

    // Dispose the leaving container only after this frame commits, so widgets
    // still reading it during the unmount don't hit a disposed container. A
    // post-commit cleanup may retain account-scoped signers owned by that
    // container, so keep it alive until the cleanup settles.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        (() async {
          try {
            await beforePreviousContainerDispose?.call();
          } finally {
            previous.dispose();
          }
        })(),
      );
    });
  }

  @override
  void dispose() {
    // Tear-offs of the same instance method compare equal (but not identical),
    // so use == to avoid detaching a controller a newer host has claimed.
    if (widget.controller._onSwap == _swap) {
      widget.controller._onSwap = null;
      widget.controller._currentContainer = null;
    }
    _container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      container: _container,
      child: KeyedSubtree(key: ValueKey(_generation), child: widget.child),
    );
  }
}
