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

          // Hard failure path. The bloc gates `failure` on
          // `notifications.isEmpty`, so we only land here when the cache
          // is also empty.
          if (state.status == NotificationFeedStatus.failure) {
            return _FailureBody(
              onRetry: () => context.read<NotificationFeedBloc>().add(
                const NotificationFeedRefreshed(),
              ),
            );
          }

          // Cached or freshly-loaded items present → render the list
          // even while the first-page refresh is still in flight. The
          // inline refresh-error banner handles the soft-failure
          // affordance via `state.refreshError`.
          if (visible.isNotEmpty) {
            return RefreshIndicator(
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
                showRefreshErrorBanner: state.refreshError,
                onRetryRefresh: () => context.read<NotificationFeedBloc>().add(
                  const NotificationFeedRefreshed(),
                ),
                onItemTap: (notification) => _onItemTap(context, notification),
                onProfileTap: (pubkey) => _navigateToProfile(context, pubkey),
                onFollowBack: (pubkey) => context
                    .read<NotificationFeedBloc>()
                    .add(NotificationFeedFollowBack(pubkey)),
              ),
            );
          }

          // Empty + still loading → full-screen spinner.
          if (state.status == NotificationFeedStatus.initial ||
              state.status == NotificationFeedStatus.loading) {
            return const Center(
              child: CircularProgressIndicator(color: VineTheme.vineGreen),
            );
          }

          // Empty + loaded → empty state with pull-to-refresh.
          return RefreshIndicator(
            color: VineTheme.onPrimary,
            backgroundColor: VineTheme.vineGreen,
            onRefresh: () async {
              context.read<NotificationFeedBloc>().add(
                const NotificationFeedRefreshed(),
              );
            },
            child: const _ScrollableEmptyState(),
          );
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
      case ActorNotification(
        :final actor,
        :final type,
        :final targetEventId,
        :final videoAddressableId,
      ):
        switch (type) {
          case NotificationKind.follow:
            _navigateToProfile(context, actor.pubkey);
          case NotificationKind.mention:
          case NotificationKind.likeComment:
          case NotificationKind.reply:
            // targetEventId is the event the resolver will walk to find the
            // root video. Falls back to the actor's profile only for mentions,
            // where the mention may have no video context at all.
            if (targetEventId != null && targetEventId.isNotEmpty) {
              final navigated = await _navigateToVideo(
                context,
                targetEventId,
                videoAddressableId: videoAddressableId,
                notificationKind: type,
              );
              if (!navigated &&
                  type == NotificationKind.mention &&
                  context.mounted) {
                _navigateToProfile(context, actor.pubkey);
              }
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

  /// Resolves the video route and pushes [PooledFullscreenVideoFeedScreen].
  ///
  /// Returns `true` if a navigation was pushed, `false` if resolution failed
  /// (resolver returned null) and no navigation occurred. The caller decides
  /// what to do on `false` — e.g. the mention branch falls back to profile.
  ///
  /// The video fetch runs concurrently after the push so the screen opens
  /// immediately; if the fetch fails or the video is unavailable a snackbar
  /// is shown on the notifications scaffold without touching the router.
  Future<bool> _navigateToVideo(
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

    final shouldAutoOpenComments =
        notificationKind == NotificationKind.comment ||
        notificationKind == NotificationKind.reply ||
        notificationKind == NotificationKind.likeComment ||
        notificationKind == NotificationKind.mention;

    // Resolve the navigation target.
    //
    // The stable-ID path (videoAddressableId set) and the raw-event-id
    // fallback are synchronous. The comment/reply fallback path may require
    // one relay round-trip to walk E/e tags, but that work belongs inside the
    // opened screen's loading stream rather than blocking the route push.
    Future<String?> routeIdFuture;
    if (videoAddressableId != null && videoAddressableId.isNotEmpty) {
      // Stable path: addressable ID works even after a metadata update.
      routeIdFuture = Future.value(videoAddressableId);
    } else if (shouldAutoOpenComments) {
      // Comment/mention path: walk E/e tags to find the root video event ID.
      routeIdFuture = NotificationTargetResolver(
        videoEventService: videoEventService,
        nostrService: ref.read(nostrServiceProvider),
      ).resolveVideoEventIdFromNotificationTarget(videoEventId);

      if (notificationKind == NotificationKind.mention) {
        // Mentions can legitimately have no video context. Preserve the
        // profile fallback by resolving before pushing only for that kind.
        final resolved = await routeIdFuture;
        if (!context.mounted) return false;
        if (resolved == null) {
          // Resolution failed — caller decides the fallback (e.g. profile).
          return false;
        }
        routeIdFuture = Future.value(resolved);
      }
    } else {
      // Fallback: no addressable ID available, use raw event ID.
      routeIdFuture = Future.value(videoEventId);
    }

    // Capture l10n and scaffold messenger before the async gap; they remain
    // valid even after the push transitions away from this view.
    final l10n = context.l10n;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    Future<List<VideoEvent>> loadVideo() async {
      try {
        final routeId = await routeIdFuture;
        if (routeId == null || routeId.isEmpty) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(l10n.notificationsVideoNotFound),
              duration: const Duration(seconds: 2),
            ),
          );
          return <VideoEvent>[];
        }

        final video = await videosRepository.fetchVideoWithStatsForRouteId(
          routeId,
        );
        if (video == null) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(l10n.notificationsVideoNotFound),
              duration: const Duration(seconds: 2),
            ),
          );
          return <VideoEvent>[];
        }
        if (videoEventService.shouldHideVideo(video)) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(l10n.notificationsVideoUnavailable),
              duration: const Duration(seconds: 2),
            ),
          );
          return <VideoEvent>[];
        }
        return [video];
      } catch (e, stackTrace) {
        Log.error(
          'Failed to fetch video for notification',
          name: 'NotificationsView',
          category: LogCategory.ui,
          error: e,
          stackTrace: stackTrace,
        );
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(l10n.notificationsVideoNotFound),
            duration: const Duration(seconds: 2),
          ),
        );
        return <VideoEvent>[];
      }
    }

    // Fetch the video concurrently. The stream is consumed by the opened
    // screen's BLoC — we never pop here to avoid touching the wrong route
    // if the user navigated away before the fetch resolved.
    final videoFuture = loadVideo();

    if (!context.mounted) return false;

    context.push(
      PooledFullscreenVideoFeedScreen.path,
      extra: PooledFullscreenVideoFeedArgs(
        videosStream: Stream.fromFuture(videoFuture),
        initialIndex: 0,
        contextTitle: l10n.notificationsFromNotification,
        autoOpenComments: shouldAutoOpenComments,
      ),
    );
    return true;
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
    required this.showRefreshErrorBanner,
    required this.onRetryRefresh,
  });

  final List<NotificationItem> notifications;
  final bool isLoadingMore;
  final bool hasMore;
  final ScrollController scrollController;
  final void Function(NotificationItem notification) onItemTap;
  final void Function(String pubkey) onProfileTap;
  final void Function(String pubkey) onFollowBack;

  /// When `true`, renders [_RefreshErrorBanner] as the list's first item so
  /// users see the cached snapshot together with a "couldn't refresh"
  /// affordance instead of a Retry-only blackout.
  final bool showRefreshErrorBanner;

  /// Callback fired by the banner's Retry button. Dispatches the same
  /// `NotificationFeedRefreshed` event the pull-to-refresh handler uses.
  final VoidCallback onRetryRefresh;

  @override
  Widget build(BuildContext context) {
    final bannerOffset = showRefreshErrorBanner ? 1 : 0;
    final itemCount =
        bannerOffset +
        notifications.length +
        (isLoadingMore && hasMore ? 1 : 0);

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      controller: scrollController,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (showRefreshErrorBanner && index == 0) {
          return _RefreshErrorBanner(onRetry: onRetryRefresh);
        }
        final dataIndex = index - bannerOffset;

        // Loading indicator at bottom.
        if (dataIndex >= notifications.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: VineTheme.vineGreen),
            ),
          );
        }

        final notification = notifications[dataIndex];
        final showDateHeader = _shouldShowDateHeader(dataIndex);

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

class _RefreshErrorBanner extends StatelessWidget {
  const _RefreshErrorBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const DivineIcon(
                icon: DivineIconName.warningCircle,
                size: 20,
                color: VineTheme.lightText,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.notificationsRefreshError,
                  style: VineTheme.bodyMediumFont(
                    color: VineTheme.secondaryText,
                  ),
                ),
              ),
              TextButton(
                onPressed: onRetry,
                child: Text(
                  // Reuse the already-translated `notificationsRetry` key
                  // so the refresh-error banner ships in every locale
                  // without adding a duplicate English-only key.
                  context.l10n.notificationsRetry,
                  style: VineTheme.labelLargeFont(color: VineTheme.vineGreen),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
