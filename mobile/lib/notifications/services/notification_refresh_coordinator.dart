// ABOUTME: Coalesces authoritative notification refresh triggers.
// ABOUTME: Used by app resume and notification route focus.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/router/app_router.dart';
import 'package:unified_logger/unified_logger.dart';

/// Why an authoritative notification refresh was requested.
enum NotificationRefreshReason {
  /// App returned to foreground after background/inactive state.
  appResume,

  /// Notifications route became visible again.
  routeFocus,
}

/// Coalesces notification refresh calls so independent liveness triggers do
/// not stampede Funnelcake.
class NotificationRefreshCoordinator {
  /// Creates a refresh coordinator.
  NotificationRefreshCoordinator({
    required NotificationRepository repository,
    Duration cooldown = const Duration(seconds: 30),
    DateTime Function()? now,
  }) : _repository = repository,
       _cooldown = cooldown,
       _now = now ?? DateTime.now;

  final NotificationRepository _repository;
  final Duration _cooldown;
  final DateTime Function() _now;

  DateTime? _lastStartedAt;
  Future<void>? _inFlight;

  /// Requests an authoritative first-page refresh.
  ///
  /// Returns the in-flight refresh if one already exists. Otherwise skips
  /// refreshes that start inside [_cooldown] unless [force] is true.
  Future<void> refresh({
    required NotificationRefreshReason reason,
    bool force = false,
  }) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final now = _now();
    final lastStartedAt = _lastStartedAt;
    if (!force &&
        lastStartedAt != null &&
        now.difference(lastStartedAt) < _cooldown) {
      return Future<void>.value();
    }

    _lastStartedAt = now;
    final future = _runRefresh(reason).whenComplete(() {
      _inFlight = null;
    });
    _inFlight = future;
    return future;
  }

  Future<void> _runRefresh(NotificationRefreshReason reason) async {
    try {
      await _repository.refresh();
    } catch (e) {
      Log.warning(
        'Notification refresh failed (${reason.name}): $e',
        name: 'NotificationRefreshCoordinator',
        category: LogCategory.api,
      );
    }
  }
}

/// Provider for the active authenticated user's refresh coordinator.
final notificationRefreshCoordinatorProvider =
    Provider<NotificationRefreshCoordinator?>((ref) {
      final repository = ref.watch(notificationRepositoryProvider);
      if (repository == null) return null;
      return NotificationRefreshCoordinator(repository: repository);
    });

/// Calls [NotificationRefreshCoordinator.refresh] when its route becomes
/// visible after another route is popped.
class NotificationFocusRefresh extends ConsumerStatefulWidget {
  /// Creates a route-focus refresh wrapper.
  const NotificationFocusRefresh({required this.child, super.key});

  /// Child notification screen content.
  final Widget child;

  @override
  ConsumerState<NotificationFocusRefresh> createState() =>
      _NotificationFocusRefreshState();
}

class _NotificationFocusRefreshState
    extends ConsumerState<NotificationFocusRefresh>
    with RouteAware {
  ModalRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == null || identical(route, _route)) return;
    final previous = _route;
    if (previous != null) {
      routeObserver.unsubscribe(this);
    }
    _route = route;
    routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _refresh();
  }

  @override
  void didPush() {
    // Initial page creation already dispatches NotificationFeedStarted. Keep
    // this hook for route transitions after construction.
  }

  void _refresh() {
    unawaited(
      ref
          .read(notificationRefreshCoordinatorProvider)
          ?.refresh(reason: NotificationRefreshReason.routeFocus),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
