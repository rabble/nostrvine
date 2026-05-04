// ABOUTME: BLoC-driven notifications list view with scroll pagination,
// ABOUTME: pull-to-refresh, date headers, and navigation to videos/profiles.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';
import 'package:openvine/notifications/bloc/notification_feed_bloc.dart';
import 'package:openvine/notifications/widgets/widgets.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/services/notification_target_resolver.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:unified_logger/unified_logger.dart';

/// The notification list UI.
///
/// Reads state from [NotificationFeedBloc] and renders notification items
/// with date headers, scroll pagination, and pull-to-refresh.
@visibleForTesting
class NotificationsView extends ConsumerStatefulWidget {
  /// Creates a [NotificationsView].
  const NotificationsView({super.key});

  @override
  ConsumerState<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends ConsumerState<NotificationsView> {
  final ScrollController _scrollController = ScrollController();

  /// Threshold (in pixels from bottom) to trigger load-more.
  static const _loadMoreThreshold = 200.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Mark all notifications as read when the screen is opened.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationFeedBloc>().add(
        const NotificationFeedMarkAllRead(),
      );
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (maxScroll - currentScroll <= _loadMoreThreshold) {
      context.read<NotificationFeedBloc>().add(
        const NotificationFeedLoadMore(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: VineTheme.surfaceContainerHigh,
      child: BlocBuilder<NotificationFeedBloc, NotificationFeedState>(
        builder: (context, state) {
          return switch (state.status) {
            NotificationFeedStatus.initial ||
            NotificationFeedStatus.loading => const Center(
              child: CircularProgressIndicator(color: VineTheme.vineGreen),
            ),
            NotificationFeedStatus.failure => _FailureBody(
              onRetry: () => context.read<NotificationFeedBloc>().add(
                const NotificationFeedRefreshed(),
              ),
            ),
            NotificationFeedStatus.loaded =>
              state.notifications.isEmpty
                  ? RefreshIndicator(
                      color: VineTheme.onPrimary,
                      backgroundColor: VineTheme.vineGreen,
                      onRefresh: () async {
                        context.read<NotificationFeedBloc>().add(
                          const NotificationFeedRefreshed(),
                        );
                      },
                      child: const _ScrollableEmptyState(),
                    )
                  : RefreshIndicator(
                      color: VineTheme.onPrimary,
                      backgroundColor: VineTheme.vineGreen,
                      onRefresh: () async {
                        context.read<NotificationFeedBloc>().add(
                          const NotificationFeedRefreshed(),
                        );
                      },
                      child: _NotificationList(
                        notifications: state.notifications,
                        isLoadingMore: state.isLoadingMore,
                        hasMore: state.hasMore,
                        scrollController: _scrollController,
                        onItemTap: (notification) =>
                            _onItemTap(context, notification),
                        onProfileTap: (pubkey) =>
                            _navigateToProfile(context, pubkey),
                        onFollowBack: (pubkey) => context
                            .read<NotificationFeedBloc>()
                            .add(NotificationFeedFollowBack(pubkey)),
                      ),
                    ),
          };
        },
      ),
    );
  }

  Future<void> _onItemTap(
    BuildContext context,
    NotificationItem notification,
  ) async {
    // Mark as read.
    context.read<NotificationFeedBloc>().add(
      NotificationFeedItemTapped(notification.id),
    );

    // Navigate based on notification type.
    switch (notification) {
      case SingleNotification():
        await _navigateForSingle(context, notification);
      case GroupedNotification():
        await _navigateForGrouped(context, notification);
    }
  }

  Future<void> _navigateForSingle(
    BuildContext context,
    SingleNotification notification,
  ) async {
    switch (notification.type) {
      case NotificationKind.follow:
        _navigateToProfile(context, notification.actor.pubkey);
      case NotificationKind.like:
      case NotificationKind.likeComment:
      case NotificationKind.comment:
      case NotificationKind.reply:
      case NotificationKind.repost:
      case NotificationKind.mention:
        if (notification.targetEventId != null) {
          await _navigateToVideo(
            context,
            notification.targetEventId!,
            notificationKind: notification.type,
          );
        }
      case NotificationKind.system:
        // System notifications don't navigate.
        break;
    }
  }

  Future<void> _navigateForGrouped(
    BuildContext context,
    GroupedNotification notification,
  ) async {
    if (notification.targetEventId != null) {
      await _navigateToVideo(
        context,
        notification.targetEventId!,
        notificationKind: notification.type,
      );
    }
  }

  Future<void> _navigateToVideo(
    BuildContext context,
    String targetId, {
    NotificationKind? notificationKind,
  }) async {
    Log.info(
      'Navigating to video from notification: $targetId',
      name: 'NotificationsView',
      category: LogCategory.ui,
    );

    final videoEventService = ref.read(videoEventServiceProvider);
    final nostrService = ref.read(nostrServiceProvider);

    // Resolve the target event ID to a video event ID.
    final resolver = NotificationTargetResolver(
      videoEventService: videoEventService,
      nostrService: nostrService,
    );
    final resolvedVideoEventId = await resolver
        .resolveVideoEventIdFromNotificationTarget(targetId);

    if (!context.mounted) return;

    if (resolvedVideoEventId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.notificationsVideoNotFound)),
      );
      return;
    }

    // fetchVideoWithStats handles cache→relay lookup and bulk-stats
    // hydration in one call, matching what feed providers do.
    VideoEvent? video;
    try {
      video = await ref
          .read(videosRepositoryProvider)
          .fetchVideoWithStats(resolvedVideoEventId);
    } catch (e) {
      Log.error(
        'Failed to fetch video: $e',
        name: 'NotificationsView',
        category: LogCategory.ui,
      );
    }

    if (!context.mounted) return;

    if (video == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.notificationsVideoNotFound),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (videoEventService.shouldHideVideo(video)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.notificationsVideoUnavailable),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final shouldAutoOpenComments =
        notificationKind == NotificationKind.comment ||
        notificationKind == NotificationKind.reply ||
        notificationKind == NotificationKind.mention ||
        notificationKind == NotificationKind.likeComment;

    context.push(
      PooledFullscreenVideoFeedScreen.path,
      extra: PooledFullscreenVideoFeedArgs(
        videosStream: Stream.value([video]),
        initialIndex: 0,
        removedIdsStream: ref.read(videoEventServiceProvider).removedVideoIds,
        contextTitle: context.l10n.notificationsFromNotification,
        autoOpenComments: shouldAutoOpenComments,
      ),
    );
  }

  void _navigateToProfile(BuildContext context, String userPubkey) {
    Log.info(
      'Navigating to profile: $userPubkey',
      name: 'NotificationsView',
      category: LogCategory.ui,
    );

    final npub = NostrKeyUtils.encodePubKey(userPubkey);
    context.push(OtherProfileScreen.pathForNpub(npub));
  }
}

// ---------------------------------------------------------------------------
// Private sub-widgets
// ---------------------------------------------------------------------------

class _ScrollableEmptyState extends StatelessWidget {
  const _ScrollableEmptyState();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: const NotificationEmptyState(),
        ),
      ),
    );
  }
}

class _FailureBody extends StatelessWidget {
  const _FailureBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: VineTheme.lightText),
          const SizedBox(height: 16),
          Text(
            context.l10n.notificationsFailedToLoad,
            style: const TextStyle(
              fontSize: 18,
              color: VineTheme.secondaryText,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: Text(
              context.l10n.notificationsRetry,
              style: const TextStyle(color: VineTheme.vineGreen),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationList extends StatelessWidget {
  const _NotificationList({
    required this.notifications,
    required this.isLoadingMore,
    required this.hasMore,
    required this.scrollController,
    required this.onItemTap,
    required this.onProfileTap,
    required this.onFollowBack,
  });

  final List<NotificationItem> notifications;
  final bool isLoadingMore;
  final bool hasMore;
  final ScrollController scrollController;
  final void Function(NotificationItem notification) onItemTap;
  final void Function(String pubkey) onProfileTap;
  final void Function(String pubkey) onFollowBack;

  @override
  Widget build(BuildContext context) {
    final itemCount = notifications.length + (isLoadingMore && hasMore ? 1 : 0);

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      controller: scrollController,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Loading indicator at bottom.
        if (index >= notifications.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: VineTheme.vineGreen),
            ),
          );
        }

        final notification = notifications[index];
        final showDateHeader = _shouldShowDateHeader(index);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDateHeader)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  LocalizedTimeFormatter.formatDateLabel(
                    context.l10n,
                    notification.timestamp.millisecondsSinceEpoch ~/ 1000,
                    locale: Localizations.localeOf(context).toLanguageTag(),
                  ),
                  style: VineTheme.labelLargeFont(
                    color: VineTheme.onSurfaceMuted,
                  ),
                ),
              ),
            NotificationListItem(
              notification: notification,
              onTap: () => onItemTap(notification),
              onProfileTap: () {
                final pubkey = _profilePubkey(notification);
                if (pubkey != null) onProfileTap(pubkey);
              },
              onFollowBack: () {
                final pubkey = _profilePubkey(notification);
                if (pubkey != null) onFollowBack(pubkey);
              },
            ),
          ],
        );
      },
    );
  }

  bool _shouldShowDateHeader(int index) {
    if (index == 0) return true;

    final current = notifications[index];
    final previous = notifications[index - 1];

    final currentLocal = current.timestamp.toLocal();
    final currentDate = DateTime(
      currentLocal.year,
      currentLocal.month,
      currentLocal.day,
    );

    final previousLocal = previous.timestamp.toLocal();
    final previousDate = DateTime(
      previousLocal.year,
      previousLocal.month,
      previousLocal.day,
    );

    return currentDate != previousDate;
  }

  /// Extracts the primary actor pubkey from a notification.
  String? _profilePubkey(NotificationItem notification) {
    return switch (notification) {
      SingleNotification(:final actor) => actor.pubkey,
      GroupedNotification(:final actors) =>
        actors.isNotEmpty ? actors.first.pubkey : null,
    };
  }
}
