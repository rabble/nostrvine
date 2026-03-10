// ABOUTME: Notifications tab for the Inbox screen showing all notification types
// ABOUTME: Extracted from NotificationsScreen, displays unified notification list

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/screens/comments/comments_screen.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/pure/explore_video_screen_pure.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/inbox/notification_date_header.dart';
import 'package:openvine/widgets/inbox/notification_item_redesigned.dart';

/// Notifications tab content for the Inbox screen.
///
/// Shows all notifications in a single unified list with date headers,
/// pull-to-refresh, and infinite scroll pagination.
class NotificationsTab extends ConsumerStatefulWidget {
  const NotificationsTab({super.key});

  @override
  ConsumerState<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends ConsumerState<NotificationsTab> {
  final ScrollController _scrollController = ScrollController();

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
    final currentScroll = _scrollController.offset;

    if (maxScroll - currentScroll <= 200) {
      ref.read(relayNotificationsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(relayNotificationsProvider);

    return asyncState.when(
      loading: () => const ColoredBox(
        color: VineTheme.surfaceContainerHigh,
        child: Center(
          child: CircularProgressIndicator(color: VineTheme.vineGreen),
        ),
      ),
      error: (error, _) => _NotificationsErrorView(
        onRetry: () {
          ref.read(relayNotificationsProvider.notifier).refresh();
        },
      ),
      data: (feedState) {
        ScreenAnalyticsService().markDataLoaded(
          'notifications',
          dataMetrics: {'notification_count': feedState.notifications.length},
        );
        final notifications = ref.watch(relayNotificationsByTypeProvider(null));

        if (notifications.isEmpty) {
          return _NotificationsEmptyView(
            onRefresh: () async {
              await ref.read(relayNotificationsProvider.notifier).refresh();
            },
          );
        }

        return ColoredBox(
          color: VineTheme.surfaceContainerHigh,
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
                      NotificationDateHeader(
                        label: _getDateHeader(notification.timestamp),
                        isFirst: index == 0,
                      ),
                    NotificationItemRedesigned(
                      notification: notification,
                      onTap: () async {
                        // Mark as read
                        await ref
                            .read(relayNotificationsProvider.notifier)
                            .markAsRead(notification.id);

                        // Navigate to appropriate screen
                        if (context.mounted) {
                          _navigateToTarget(context, notification);
                        }
                      },
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
      const weekdays = [
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
      'Notification clicked: ${notification.navigationAction} '
      '-> ${notification.navigationTarget}',
      name: 'NotificationsTab',
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
      case 'open_profile':
        if (notification.navigationTarget != null) {
          _navigateToProfile(context, notification.navigationTarget!);
        }
      case 'none':
        // System notifications don't need navigation
        break;
      default:
        Log.warning(
          'Unknown navigation action: '
          '${notification.navigationAction}',
          name: 'NotificationsTab',
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
      name: 'NotificationsTab',
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
        name: 'NotificationsTab',
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
          name: 'NotificationsTab',
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
      name: 'NotificationsTab',
      category: LogCategory.ui,
    );

    final npub = NostrKeyUtils.encodePubKey(userPubkey);
    context.push(OtherProfileScreen.pathForNpub(npub));
  }
}

class _NotificationsErrorView extends StatelessWidget {
  const _NotificationsErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: VineTheme.surfaceContainerHigh,
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
            Text(
              'Failed to load notifications',
              style: VineTheme.titleMediumFont(
                color: VineTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: VineTheme.labelLargeFont(color: VineTheme.vineGreen),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsEmptyView extends StatelessWidget {
  const _NotificationsEmptyView({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: VineTheme.surfaceContainerHigh,
      child: RefreshIndicator(
        semanticsLabel: 'checking for new notifications',
        color: VineTheme.onPrimary,
        backgroundColor: VineTheme.vineGreen,
        onRefresh: onRefresh,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'No activity  yet',
                        textAlign: TextAlign.center,
                        style: VineTheme.titleMediumFont(
                          fontSize: 20,
                          height: 28 / 20,
                          color: VineTheme.onSurfaceMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'When people interact with your content, '
                        "you'll see it here",
                        textAlign: TextAlign.center,
                        style: VineTheme.bodyMediumFont(
                          color: VineTheme.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
