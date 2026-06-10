// ABOUTME: Coalesces authoritative notification refresh triggers.
// ABOUTME: Used by app resume to keep the repository snapshot fresh.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:unified_logger/unified_logger.dart';

/// Why an authoritative notification refresh was requested.
enum NotificationRefreshReason {
  /// App returned to foreground after background/inactive state.
  appResume,
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
