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
  const NotificationsView({this.kindFilter, super.key});

  /// When non-null, only notifications whose [NotificationItem.type] matches
  /// the filter are rendered. Used by the inbox tabs scaffold.
  ///
  /// `like` matches both [VideoNotification]s of kind `like` and
  /// [ActorNotification]s of kind `likeComment` so the Likes tab surfaces
  /// reactions on both videos and comments.
  final NotificationKind? kindFilter;

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

    // Mark all notifications as read in the bloc when the screen is opened.
    //
    // The legacy Riverpod cache that powers the bottom-nav badge and inbox
    // toggle count is synced by the page-level wrapper
    // ([InboxNotificationsPage] / [NotificationsPage]), not from here, so
    // the side effect fires once per inbox open instead of once per
    // [NotificationsView] mount (the inbox mounts five — one per filter
    // tab).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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

  /// Returns [items] filtered by [NotificationsView.kindFilter].
  ///
  /// `like` matches both video likes and comment likes so the Likes tab
  /// surfaces reactions on either target.
  List<NotificationItem> _applyFilter(List<NotificationItem> items) {
    final filter = widget.kindFilter;
    if (filter == null) return items;
    return items.where((n) {
      if (n.type == filter) return true;
      if (filter == NotificationKind.like &&
          n.type == NotificationKind.likeComment) {
        return true;
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: VineTheme.surfaceContainerHigh,
      child: BlocBuilder<NotificationFeedBloc, NotificationFeedState>(
        builder: (context, state) {
          final visible = _applyFilter(state.notifications);
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
              visible.isEmpty
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
                        notifications: visible,
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

    switch (notification) {
      case VideoNotification(
        :final videoEventId,
        :final videoAddressableId,
        :final type,
      ):
        await _navigateToVideo(
          context,
          videoEventId,
          videoAddressableId: videoAddressableId,
          notificationKind: type,
        );
      case ActorNotification(:final actor, :final type, :final targetEventId):
        switch (type) {
          case NotificationKind.follow:
          case NotificationKind.mention:
            _navigateToProfile(context, actor.pubkey);
          case NotificationKind.likeComment:
          case NotificationKind.reply:
            // targetEventId is the kind 1111 comment; the resolver
            // walks its E tag to the root video.
            if (targetEventId != null && targetEventId.isNotEmpty) {
              await _navigateToVideo(
                context,
                targetEventId,
                notificationKind: type,
              );
            } else {
              _navigateToProfile(context, actor.pubkey);
            }
          case NotificationKind.system:
            break;
          case NotificationKind.like:
          case NotificationKind.comment:
          case NotificationKind.repost:
            // Not represented as ActorNotification, but pattern-match
            // exhaustivity requires these.
            break;
        }
    }
  }

  Future<void> _navigateToVideo(
    BuildContext context,
    String videoEventId, {
    String? videoAddressableId,
    NotificationKind? notificationKind,
  }) async {
    Log.info(
      'Navigating to video from notification: '
      'addressable=$videoAddressableId eventId=$videoEventId',
      name: 'NotificationsView',
      category: LogCategory.ui,
    );

    final videoEventService = ref.read(videoEventServiceProvider);
    final videosRepository = ref.read(videosRepositoryProvider);

    // Use the stable NIP-33 addressable ID whenever the notification payload
    // includes one. It survives metadata updates because it's keyed on
    // (kind:pubkey:d-tag) rather than the mutable event hash.
    final isComment =
        notificationKind == NotificationKind.comment ||
        notificationKind == NotificationKind.reply ||
        notificationKind == NotificationKind.likeComment;

    // Resolve the navigation target.
    String routeId;
    if (videoAddressableId != null && videoAddressableId.isNotEmpty) {
      // Stable path: addressable ID works even after a metadata update.
      routeId = videoAddressableId;
    } else if (isComment) {
      // Comment path: walk E/e tags to find the root video event ID.
      final resolved = await NotificationTargetResolver(
        videoEventService: videoEventService,
        nostrService: ref.read(nostrServiceProvider),
      ).resolveVideoEventIdFromNotificationTarget(videoEventId);

      if (!context.mounted) return;

      if (resolved == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.notificationsVideoNotFound),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
      routeId = resolved;
    } else {
      // Fallback: no addressable ID available, use raw event ID.
      routeId = videoEventId;
    }

    VideoEvent? video;
    try {
      video = await videosRepository.fetchVideoWithStatsForRouteId(routeId);
      if (!context.mounted) return;
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

    context.push(
      PooledFullscreenVideoFeedScreen.path,
      extra: PooledFullscreenVideoFeedArgs(
        videosStream: Stream.value([video]),
        initialIndex: 0,
        contextTitle: context.l10n.notificationsFromNotification,
        autoOpenComments: isComment,
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
          const DivineIcon(
            icon: DivineIconName.warningCircle,
            size: 64,
            color: VineTheme.lightText,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.notificationsFailedToLoad,
            style: VineTheme.bodyLargeFont(color: VineTheme.secondaryText),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: Text(
              context.l10n.notificationsRetry,
              style: VineTheme.labelLargeFont(color: VineTheme.vineGreen),
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
      VideoNotification(:final actors) =>
        actors.isNotEmpty ? actors.first.pubkey : null,
      ActorNotification(:final actor) => actor.pubkey,
    };
  }
}
