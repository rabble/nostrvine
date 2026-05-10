// ABOUTME: ConsumerStatefulWidget page that provides NotificationFeedBloc
// ABOUTME: to the notifications view. Bridges Riverpod dependencies into
// ABOUTME: BLoC and clears the legacy Riverpod unread cache on open.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Hide the bloc's NotificationFeedState — this file uses the
// identically-named state from relay_notifications_provider via the
// Riverpod listener below.
import 'package:openvine/notifications/bloc/notification_feed_bloc.dart'
    hide NotificationFeedState;
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/notifications/view/notifications_view.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/relay_notifications_provider.dart'
    show NotificationFeedState, relayNotificationsProvider;

/// Top-level page for the notifications tab.
///
/// Reads dependencies from Riverpod, creates [NotificationFeedBloc], and
/// provides it to [NotificationsView]. Also marks the legacy Riverpod
/// unread cache as read on open so the bottom-nav badge clears immediately
/// — see [_NotificationsPageState._maybeSyncRelayNotificationsRead].
class NotificationsPage extends ConsumerStatefulWidget {
  /// Creates a [NotificationsPage].
  const NotificationsPage({super.key});

  /// Route name for this screen.
  static const routeName = 'notifications';

  /// Path for this route.
  static const path = '/notifications';

  /// Path for this route with index.
  static const pathWithIndex = '/notifications/:index';

  /// Build path for a specific index.
  static String pathForIndex([int? index]) =>
      index == null ? path : '$path/$index';

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  /// Whether the per-open Riverpod sync has already fired. See
  /// [_maybeSyncRelayNotificationsRead].
  bool _relaySynced = false;

  @override
  void initState() {
    super.initState();
    // Sync the legacy Riverpod unread cache the first time the provider
    // yields AsyncData. `fireImmediately: true` covers the warm-cache
    // case (the bottom-nav already keeps the provider alive); the
    // listener also covers the cold-start case where the provider is
    // still resolving on page open.
    ref.listenManual<AsyncValue<NotificationFeedState>>(
      relayNotificationsProvider,
      (_, next) => _maybeSyncRelayNotificationsRead(next),
      fireImmediately: true,
    );
  }

  /// Marks all notifications read in the legacy Riverpod cache that powers
  /// the bottom-nav badge. Fires once per page open, the first time
  /// [relayNotificationsProvider] yields an [AsyncData] state — handles
  /// both warm-cache opens (provider already loaded) and cold-start opens
  /// (still resolving) without firing a no-op API write when there is
  /// nothing unread.
  void _maybeSyncRelayNotificationsRead(
    AsyncValue<NotificationFeedState> asyncState,
  ) {
    if (_relaySynced) return;
    final state = asyncState.whenOrNull(data: (s) => s);
    if (state == null) return;
    _relaySynced = true;
    final hasUnread =
        state.unreadCount > 0 || state.notifications.any((n) => !n.isRead);
    if (!hasUnread) return;
    ref.read(relayNotificationsProvider.notifier).markAllAsRead();
  }

  @override
  Widget build(BuildContext context) {
    final notificationRepository = ref.watch(notificationRepositoryProvider);

    // Dependencies not yet available (e.g. ProfileRepository during auth).
    if (notificationRepository == null) {
      return const ColoredBox(
        color: VineTheme.backgroundColor,
        child: Center(
          child: CircularProgressIndicator(color: VineTheme.vineGreen),
        ),
      );
    }

    final followRepository = ref.watch(followRepositoryProvider);

    return BlocProvider(
      create: (_) => NotificationFeedBloc(
        notificationRepository: notificationRepository,
        followRepository: followRepository,
      )..add(const NotificationFeedStarted()),
      child: const NotificationsView(),
    );
  }
}
