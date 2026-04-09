// TODO(notifications-refactor): Remove after migration is verified
// ABOUTME: Notifications screen displaying user's social interactions and system updates
// ABOUTME: Shows likes, comments, follows, mentions, reposts with filtering and read state

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/mixins/scroll_pagination_mixin.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/screens/comments/comments_screen.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/pure/explore_video_screen_pure.dart';
import 'package:openvine/screens/settings/invites_screen.dart';
import 'package:openvine/services/notification_target_resolver.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/notification_list_item.dart';
import 'package:time_formatter/time_formatter.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'notifications';

  /// Path for this route.
  static const path = '/notifications';

  /// Path for this route with index.
  static const pathWithIndex = '/notifications/:index';

  /// Build path for a specific index.
  static String pathForIndex([int? index]) =>
      index == null ? path : '$path/$index';

  const NotificationsScreen({
    this.skipInitialBootstrapForTesting = false,
    super.key,
  });

  @visibleForTesting
  final bool skipInitialBootstrapForTesting;

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTabIndex = 0;
  bool _isBootstrappingFreshFeed = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_handleTabChanged);
    if (widget.skipInitialBootstrapForTesting) {
      _isBootstrappingFreshFeed = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(relayNotificationsProvider.notifier).markAllAsRead();
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrapFreshFeed());
      // Check invite status when notifications tab opens
      context.read<InviteStatusCubit>().load();
    });
  }

  Future<void> _bootstrapFreshFeed() async {
    ref.invalidate(relayNotificationsProvider);

    try {
      await ref.read(relayNotificationsProvider.future);
      if (!mounted) return;
      await ref.read(relayNotificationsProvider.notifier).markAllAsRead();
    } finally {
      if (mounted) {
        setState(() {
          _isBootstrappingFreshFeed = false;
        });
      }
    }
  }

  void _handleTabChanged() {
    if (_activeTabIndex == _tabController.index) return;
    setState(() {
      _activeTabIndex = _tabController.index;
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isBootstrappingFreshFeed) {
      return const ColoredBox(
        color: VineTheme.backgroundColor,
        child: Center(
          child: CircularProgressIndicator(color: VineTheme.vineGreen),
        ),
      );
    }

    // AppShell provides the Scaffold and AppBar, so this is just the body content
    return Column(
      children: [
        // Tab bar for filtering notifications
        Material(
          color: VineTheme.navGreen,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.only(left: 16),
            indicatorColor: VineTheme.tabIndicatorGreen,
            indicatorWeight: 4,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: VineTheme.transparent,
            labelColor: VineTheme.whiteText,
            unselectedLabelColor: VineTheme.tabIconInactive,
            labelStyle: VineTheme.tabTextStyle(),
            unselectedLabelStyle: VineTheme.tabTextStyle(
              color: VineTheme.tabIconInactive,
            ),
            labelPadding: const EdgeInsets.symmetric(horizontal: 14),
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Likes'),
              Tab(text: 'Comments'),
              Tab(text: 'Follows'),
              Tab(text: 'Reposts'),
            ],
          ),
        ),
        // Notification lists with swipe support
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _NotificationTabContent(
                filter: null,
                isActive: _activeTabIndex == 0,
              ),
              _NotificationTabContent(
                filter: NotificationType.like,
                isActive: _activeTabIndex == 1,
              ),
              _NotificationTabContent(
                filter: NotificationType.comment,
                isActive: _activeTabIndex == 2,
              ),
              _NotificationTabContent(
                filter: NotificationType.follow,
                isActive: _activeTabIndex == 3,
              ),
              _NotificationTabContent(
                filter: NotificationType.repost,
                isActive: _activeTabIndex == 4,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Content for a single notification tab. Each tab has its own scroll
/// controller so scroll positions are preserved when switching tabs.
class _NotificationTabContent extends ConsumerStatefulWidget {
  const _NotificationTabContent({
    required this.filter,
    required this.isActive,
  });

  final NotificationType? filter;
  final bool isActive;

  @override
  ConsumerState<_NotificationTabContent> createState() =>
      _NotificationTabContentState();
}

class _NotificationTabContentState
    extends ConsumerState<_NotificationTabContent>
    with ScrollPaginationMixin {
  final ScrollController _scrollController = ScrollController();
  bool _isRequestingFilteredTopUp = false;

  @override
  ScrollController get paginationScrollController => _scrollController;

  @override
  bool canLoadMore() {
    final feedState = ref.read(relayNotificationsProvider).asData?.value;
    return feedState != null &&
        feedState.hasMoreContent &&
        !feedState.isLoadingMore &&
        !feedState.isRefreshing;
  }

  @override
  FutureOr<void> onLoadMore() =>
      ref.read(relayNotificationsProvider.notifier).loadMore();

  @override
  void initState() {
    super.initState();
    initPagination();
  }

  @override
  void dispose() {
    disposePagination();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(relayNotificationsProvider);

    return asyncState.when(
      loading: () => const ColoredBox(
        color: VineTheme.backgroundColor,
        child: Center(
          child: CircularProgressIndicator(color: VineTheme.vineGreen),
        ),
      ),
      error: (error, _) => ColoredBox(
        color: VineTheme.backgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: VineTheme.lightText,
              ),
              const SizedBox(height: 16),
              const Text(
                'Failed to load notifications',
                style: TextStyle(fontSize: 18, color: VineTheme.secondaryText),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  ref.read(relayNotificationsProvider.notifier).refresh();
                },
                child: const Text(
                  'Retry',
                  style: TextStyle(color: VineTheme.vineGreen),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (feedState) {
        ScreenAnalyticsService().markDataLoaded(
          'notifications',
          dataMetrics: {'notification_count': feedState.notifications.length},
        );
        final notifications = ref.watch(
          relayNotificationsByTypeProvider(widget.filter),
        );

        _maybeLoadMoreForFilteredTab(feedState, notifications);
        final isSearchingForFilteredContent = _isSearchingForFilteredContent(
          feedState,
          notifications,
        );

        if (notifications.isEmpty) {
          return ColoredBox(
            color: VineTheme.backgroundColor,
            child: RefreshIndicator(
              semanticsLabel: 'checking for new notifications',
              color: VineTheme.onPrimary,
              backgroundColor: VineTheme.vineGreen,
              onRefresh: () async {
                await ref.read(relayNotificationsProvider.notifier).refresh();
              },
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: constraints.maxHeight,
                    child: Center(
                      child: isSearchingForFilteredContent
                          ? _FilteredTabLoadingState(
                              filterName: _getFilterName(widget.filter!),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.notifications_none,
                                  size: 64,
                                  color: VineTheme.lightText,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  widget.filter == null
                                      ? 'No notifications yet'
                                      : 'No ${_getFilterName(widget.filter!)}'
                                            ' notifications',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: VineTheme.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'When people interact with your content,\n'
                                  "you'll see it here",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: VineTheme.lightText,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return ColoredBox(
          color: VineTheme.backgroundColor,
          child: RefreshIndicator(
            semanticsLabel: 'checking for new notifications',
            color: VineTheme.onPrimary,
            backgroundColor: VineTheme.vineGreen,
            onRefresh: () async {
              await ref.read(relayNotificationsProvider.notifier).refresh();
            },
            child: BlocBuilder<InviteStatusCubit, InviteStatusState>(
              builder: (context, inviteState) {
                final showInviteCard =
                    widget.filter == null && inviteState.hasUnclaimedCodes;
                final inviteCardOffset = showInviteCard ? 1 : 0;
                final hasLoadingIndicator =
                    feedState.hasMoreContent &&
                    feedState.isLoadingMore &&
                    !feedState.isRefreshing;

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  controller: _scrollController,
                  itemCount:
                      notifications.length +
                      inviteCardOffset +
                      (hasLoadingIndicator ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Invite card at top of All tab
                    if (showInviteCard && index == 0) {
                      return _InviteNotificationCard(
                        count: inviteState.unclaimedCount,
                      );
                    }
                    final adjustedIndex = index - inviteCardOffset;

                    // Loading indicator at bottom
                    if (adjustedIndex >= notifications.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: VineTheme.vineGreen,
                          ),
                        ),
                      );
                    }

                    final notification = notifications[adjustedIndex];
                    final showDateHeader = _shouldShowDateHeader(
                      adjustedIndex,
                      notifications,
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showDateHeader)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              TimeFormatter.formatDateLabel(
                                notification.timestamp.millisecondsSinceEpoch ~/
                                    1000,
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: VineTheme.secondaryText,
                              ),
                            ),
                          ),
                        NotificationListItem(
                          notification: notification,
                          onTap: () async {
                            // Mark as read
                            await ref
                                .read(relayNotificationsProvider.notifier)
                                .markAsRead(notification.id);

                            // Navigate to appropriate screen based on type
                            if (context.mounted) {
                              await _navigateToTarget(context, notification);
                            }
                          },
                          onProfileTap: () {
                            _navigateToProfile(
                              context,
                              notification.actorPubkey,
                            );
                          },
                        ),
                        if (adjustedIndex < notifications.length - 1)
                          const Divider(
                            height: 1,
                            thickness: 0.5,
                            color: VineTheme.onSurfaceMuted,
                            indent: 72,
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _maybeLoadMoreForFilteredTab(
    NotificationFeedState feedState,
    List<NotificationModel> notifications,
  ) {
    final needsTopUp =
        widget.isActive &&
        widget.filter != null &&
        notifications.isEmpty &&
        feedState.hasMoreContent &&
        !feedState.isLoadingMore &&
        !feedState.isRefreshing &&
        !_isRequestingFilteredTopUp;

    if (!needsTopUp) return;

    Log.info(
      'NotificationsScreen: topping up ${_getFilterName(widget.filter!)} tab '
      'because current page has no matching items',
      name: 'NotificationsScreen',
      category: LogCategory.ui,
    );

    _isRequestingFilteredTopUp = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref.read(relayNotificationsProvider.notifier).loadMore();
      if (!mounted) return;
      setState(() {
        _isRequestingFilteredTopUp = false;
      });
    });
  }

  bool _isSearchingForFilteredContent(
    NotificationFeedState feedState,
    List<NotificationModel> notifications,
  ) {
    return widget.filter != null &&
        widget.isActive &&
        notifications.isEmpty &&
        (feedState.isLoadingMore || _isRequestingFilteredTopUp) &&
        feedState.hasMoreContent;
  }

  String _getFilterName(NotificationType type) {
    switch (type) {
      case NotificationType.like:
        return 'like';
      case NotificationType.comment:
        return 'comment';
      case NotificationType.follow:
        return 'follow';
      case NotificationType.mention:
        return 'mention';
      case NotificationType.repost:
        return 'repost';
      case NotificationType.system:
        return 'system';
    }
  }

  bool _shouldShowDateHeader(int index, List<NotificationModel> notifications) {
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

  Future<void> _navigateToTarget(
    BuildContext context,
    NotificationModel notification,
  ) async {
    Log.info(
      '🔔 Notification clicked: ${notification.navigationAction} -> ${notification.navigationTarget}',
      name: 'NotificationsScreen',
      category: LogCategory.ui,
    );

    switch (notification.navigationAction) {
      case 'open_video':
        if (notification.navigationTarget != null) {
          final resolver = NotificationTargetResolver(
            videoEventService: ref.read(videoEventServiceProvider),
            nostrService: ref.read(nostrServiceProvider),
          );
          final resolvedVideoEventId = await resolver
              .resolveVideoEventIdFromNotificationTarget(
                notification.navigationTarget!,
              );

          if (!context.mounted) {
            return;
          }

          if (resolvedVideoEventId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Video not found')),
            );
            return;
          }

          await _navigateToVideo(
            context,
            resolvedVideoEventId,
            notificationType: notification.type,
          );
        }
      case 'open_profile':
        if (notification.navigationTarget != null) {
          _navigateToProfile(context, notification.navigationTarget!);
        }
      case 'none':
        // System notifications don't need navigation
        break;
      default:
        Log.warning(
          'Unknown navigation action: ${notification.navigationAction}',
          name: 'NotificationsScreen',
          category: LogCategory.ui,
        );
    }
  }

  Future<void> _navigateToVideo(
    BuildContext context,
    String videoEventId, {
    NotificationType? notificationType,
  }) async {
    Log.info(
      'Navigating to video: $videoEventId',
      name: 'NotificationsScreen',
      category: LogCategory.ui,
    );

    // Get video from video event service (search all feed types)
    final videoEventService = ref.read(videoEventServiceProvider);

    // Use the service's built-in search across all subscription types
    var video = videoEventService.getVideoById(videoEventId);

    // If not found in cache, try fetching from Nostr
    if (video == null) {
      Log.info(
        'Video not in cache, fetching from Nostr: $videoEventId',
        name: 'NotificationsScreen',
        category: LogCategory.ui,
      );

      try {
        final nostrService = ref.read(nostrServiceProvider);
        final event = await nostrService.fetchEventById(videoEventId);
        if (event != null) {
          video = VideoEvent.fromNostrEvent(event);
        }
      } catch (e) {
        Log.error(
          'Failed to fetch video from Nostr: $e',
          name: 'NotificationsScreen',
          category: LogCategory.ui,
        );
      }
    }

    if (!context.mounted) return;

    if (video == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video not found'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (videoEventService.shouldHideVideo(video)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video unavailable'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final shouldAutoOpenComments = notificationType == NotificationType.comment;
    final videoForNav = video;

    // Navigate to video player with this specific video
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (navContext) {
          if (shouldAutoOpenComments) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (navContext.mounted) {
                CommentsScreen.show(navContext, videoForNav);
              }
            });
          }
          return ExploreVideoScreenPure(
            startingVideo: videoForNav,
            videoList: [videoForNav],
            contextTitle: 'From Notification',
            startingIndex: 0,
            useLocalActiveState: true,
          );
        },
      ),
    );
  }

  void _navigateToProfile(BuildContext context, String userPubkey) {
    Log.info(
      'Navigating to profile: $userPubkey',
      name: 'NotificationsScreen',
      category: LogCategory.ui,
    );

    final npub = NostrKeyUtils.encodePubKey(userPubkey);
    context.push(OtherProfileScreen.pathForNpub(npub));
  }
}

class _FilteredTabLoadingState extends StatelessWidget {
  const _FilteredTabLoadingState({required this.filterName});

  final String filterName;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: VineTheme.vineGreen),
        const SizedBox(height: 16),
        Text(
          'Loading $filterName notifications...',
          style: const TextStyle(
            fontSize: 18,
            color: VineTheme.secondaryText,
          ),
        ),
      ],
    );
  }
}

class _InviteNotificationCard extends StatelessWidget {
  const _InviteNotificationCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count == 1
        ? 'You have 1 invite to share with a friend!'
        : 'You have $count invites to share with friends!';

    return InkWell(
      onTap: () => context.push(InvitesScreen.path),
      child: Container(
        padding: const EdgeInsets.all(16),
        color: VineTheme.cardBackground,
        child: Row(
          spacing: 12,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: VineTheme.vineGreen,
                shape: BoxShape.circle,
              ),
              child: const DivineIcon(
                icon: DivineIconName.shareNetwork,
                color: VineTheme.backgroundColor,
              ),
            ),
            Expanded(
              child: Text(
                label,
                style: VineTheme.bodyMediumFont(),
              ),
            ),
            const DivineIcon(
              icon: DivineIconName.caretRight,
              color: VineTheme.lightText,
            ),
          ],
        ),
      ),
    );
  }
}
