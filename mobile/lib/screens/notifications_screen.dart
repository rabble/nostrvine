// ABOUTME: Notifications screen displaying user's social interactions and system updates
// ABOUTME: Shows likes, comments, follows, mentions, reposts with filtering and read state

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart'
    hide LogCategory, NotificationModel, NotificationType;
import 'package:openvine/models/notification_model.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/screens/comments/comments_screen.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/pure/explore_video_screen_pure.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/notification_list_item.dart';

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

  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  NotificationType? _selectedFilter;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;

    if (maxScroll - currentScroll <= 200) {
      ref.read(relayNotificationsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
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
            dividerColor: Colors.transparent,
            labelColor: VineTheme.whiteText,
            unselectedLabelColor: VineTheme.tabIconInactive,
            labelStyle: VineTheme.tabTextStyle(),
            unselectedLabelStyle: VineTheme.tabTextStyle(
              color: VineTheme.tabIconInactive,
            ),
            labelPadding: const EdgeInsets.symmetric(horizontal: 14),
            onTap: (index) {
              setState(() {
                switch (index) {
                  case 0:
                    _selectedFilter = null;
                  case 1:
                    _selectedFilter = NotificationType.like;
                  case 2:
                    _selectedFilter = NotificationType.comment;
                  case 3:
                    _selectedFilter = NotificationType.follow;
                  case 4:
                    _selectedFilter = NotificationType.repost;
                }
              });
            },
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Likes'),
              Tab(text: 'Comments'),
              Tab(text: 'Follows'),
              Tab(text: 'Reposts'),
            ],
          ),
        ),
        // Notification list
        Expanded(child: _buildNotificationList()),
      ],
    );
  }

  Widget _buildNotificationList() {
    final asyncState = ref.watch(relayNotificationsProvider);

    return asyncState.when(
      loading: () => Container(
        color: VineTheme.backgroundColor,
        child: const Center(
          child: CircularProgressIndicator(color: VineTheme.vineGreen),
        ),
      ),
      error: (error, _) => Container(
        color: VineTheme.backgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: VineTheme.lightText),
              const SizedBox(height: 16),
              Text(
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
        final notifications = ref.watch(
          relayNotificationsByTypeProvider(_selectedFilter),
        );

        if (notifications.isEmpty) {
          return Container(
            color: VineTheme.backgroundColor,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: VineTheme.lightText,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedFilter == null
                        ? 'No notifications yet'
                        : 'No ${_getFilterName(_selectedFilter!)} notifications',
                    style: TextStyle(
                      fontSize: 18,
                      color: VineTheme.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "When people interact with your content,\n"
                    "you'll see it here",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: VineTheme.lightText),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          color: VineTheme.backgroundColor,
          child: RefreshIndicator(
            semanticsLabel: 'checking for new notifications',
            color: VineTheme.onPrimary,
            backgroundColor: VineTheme.vineGreen,
            onRefresh: () async {
              await ref.read(relayNotificationsProvider.notifier).refresh();
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              controller: _scrollController,
              itemCount:
                  notifications.length +
                  (feedState.hasMoreContent && feedState.isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                // Loading indicator at bottom
                if (index >= notifications.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: VineTheme.vineGreen,
                      ),
                    ),
                  );
                }

                final notification = notifications[index];
                final showDateHeader = _shouldShowDateHeader(
                  index,
                  notifications,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showDateHeader)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          _getDateHeader(notification.timestamp),
                          style: TextStyle(
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
                          _navigateToTarget(context, notification);
                        }
                      },
                    ),
                    if (index < notifications.length - 1)
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: VineTheme.onSurfaceMuted,
                        indent: 72,
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
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

    final currentDate = DateTime(
      current.timestamp.year,
      current.timestamp.month,
      current.timestamp.day,
    );

    final previousDate = DateTime(
      previous.timestamp.year,
      previous.timestamp.month,
      previous.timestamp.day,
    );

    return currentDate != previousDate;
  }

  String _getDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      final weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return weekdays[date.weekday - 1];
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _navigateToTarget(BuildContext context, NotificationModel notification) {
    Log.info(
      '🔔 Notification clicked: ${notification.navigationAction} -> ${notification.navigationTarget}',
      name: 'NotificationsScreen',
      category: LogCategory.ui,
    );

    switch (notification.navigationAction) {
      case 'open_video':
        if (notification.navigationTarget != null) {
          _navigateToVideo(
            context,
            notification.navigationTarget!,
            notificationType: notification.type,
          );
        }
        break;
      case 'open_profile':
        if (notification.navigationTarget != null) {
          _navigateToProfile(context, notification.navigationTarget!);
        }
        break;
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
