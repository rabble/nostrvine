// ABOUTME: Screen for displaying videos from a curated NIP-51 kind 30005 list
// ABOUTME: Shows videos in a grid with tap-to-play navigation

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:unified_logger/unified_logger.dart';

class CuratedListFeedScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'list';

  /// Base path for list routes.
  static const basePath = '/list';

  /// Path for this route.
  static const path = '/list/:listId';

  /// Build path for a specific list.
  static String pathForId(String listId) {
    final encodedId = Uri.encodeComponent(listId);
    return '$basePath/$encodedId';
  }

  const CuratedListFeedScreen({
    required this.listId,
    required this.listName,
    this.videoIds,
    this.authorPubkey,
    super.key,
  });

  final String listId;
  final String listName;

  /// Optional video IDs to display directly (for discovered lists not in local storage)
  final List<String>? videoIds;

  /// Optional author pubkey to display who created the list
  final String? authorPubkey;

  @override
  ConsumerState<CuratedListFeedScreen> createState() =>
      _CuratedListFeedScreenState();
}

class _CuratedListFeedScreenState extends ConsumerState<CuratedListFeedScreen> {
  int? _activeVideoIndex;
  bool _isTogglingSubscription = false;

  @override
  Widget build(BuildContext context) {
    // Use direct video IDs if provided (for discovered lists not in local storage)
    // Otherwise look up by list ID from local storage
    final videosAsync = widget.videoIds != null
        ? ref.watch(videoEventsByIdsProvider(widget.videoIds!))
        : ref.watch(curatedListVideoEventsProvider(widget.listId));

    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: _activeVideoIndex == null
          ? DiVineAppBar(
              titleWidget: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.listName, style: VineTheme.titleLargeFont()),
                  const SizedBox(height: 2),
                  _buildSubheading(),
                ],
              ),
              showBackButton: true,
              onBackPressed: context.pop,
              actions: [_buildSubscribeAction()],
            )
          : null,
      body: videosAsync.when(
        data: (videos) {
          if (videos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.video_library,
                    size: 64,
                    color: VineTheme.secondaryText,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.curatedListEmptyTitle,
                    style: const TextStyle(
                      color: VineTheme.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.curatedListEmptySubtitle,
                    style: const TextStyle(
                      color: VineTheme.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          ScreenAnalyticsService().markDataLoaded(
            'curated_list',
            dataMetrics: {'video_count': videos.length},
          );

          // If in video mode, show fullscreen video player
          if (_activeVideoIndex != null) {
            return _buildVideoPlayer(videos);
          }

          // Otherwise show grid
          return _buildVideoGrid(videos);
        },
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: VineTheme.vineGreen),
              const SizedBox(height: 16),
              Text(
                context.l10n.curatedListLoadingVideos,
                style: const TextStyle(
                  color: VineTheme.secondaryText,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: VineTheme.likeRed),
              const SizedBox(height: 16),
              Text(
                context.l10n.curatedListFailedToLoad,
                style: const TextStyle(
                  color: VineTheme.likeRed,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  error.toString(),
                  style: const TextStyle(
                    color: VineTheme.secondaryText,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(curatedListVideoEventsProvider(widget.listId));
                },
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.commonRetry),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VineTheme.vineGreen,
                  foregroundColor: VineTheme.backgroundColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoGrid(List<VideoEvent> videos) {
    return ComposableVideoGrid(
      videos: videos,
      useMasonryLayout: true,
      onVideoTap: (videoList, index) {
        Log.info(
          'Tapped video in curated list: ${videoList[index].id}',
          category: LogCategory.ui,
        );
        setState(() {
          _activeVideoIndex = index;
        });
      },
      onRefresh: () async {
        // Refresh by invalidating the provider
        ref.invalidate(curatedListVideoEventsProvider(widget.listId));
      },
      emptyBuilder: () => Center(
        child: Text(
          context.l10n.curatedListNoVideosAvailable,
          style: const TextStyle(color: VineTheme.secondaryText),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(List<VideoEvent> videos) {
    if (videos.isEmpty || _activeVideoIndex! >= videos.length) {
      return Center(
        child: Text(
          context.l10n.curatedListVideoNotAvailable,
          style: const TextStyle(color: VineTheme.secondaryText),
        ),
      );
    }

    // Use Stack with back button overlay to exit video mode
    return Stack(
      children: [
        PooledFullscreenVideoFeedScreen(
          videosStream: Stream.value(videos),
          initialIndex: _activeVideoIndex!,
          removedIdsStream: ref.read(videoEventServiceProvider).removedVideoIds,
          contextTitle: widget.listName,
          trafficSource: ViewTrafficSource.search,
        ),
        // Back button overlay to exit video mode
        PositionedDirectional(
          top: 50,
          start: 16,
          child: SafeArea(
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: VineTheme.scrim50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: VineTheme.whiteText),
              ),
              onPressed: () {
                setState(() {
                  _activeVideoIndex = null;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Build the subheading showing the creator and video count.
  Widget _buildSubheading() {
    final videoCount = widget.videoIds?.length ?? 0;
    final videoText = context.l10n.listVideoCount(videoCount);
    final authorPubkey = widget.authorPubkey;

    if (authorPubkey != null) {
      return GestureDetector(
        onTap: () {
          final npub = NostrKeyUtils.encodePubKey(authorPubkey);
          context.push(OtherProfileScreen.pathForNpub(npub));
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.listByAuthorPrefix,
              style: const TextStyle(
                color: VineTheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            Flexible(
              flex: 0,
              child: UserName.fromPubKey(
                widget.authorPubkey!,
                style: const TextStyle(
                  color: VineTheme.whiteText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              ' • $videoText',
              style: const TextStyle(
                color: VineTheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    // No author - just show video count
    return Text(
      videoText,
      style: const TextStyle(color: VineTheme.onSurfaceVariant, fontSize: 12),
    );
  }

  DiVineAppBarAction _buildSubscribeAction() {
    final serviceAsync = ref.watch(curatedListsStateProvider);
    final service = ref.read(curatedListsStateProvider.notifier).service;
    final isSubscribed =
        serviceAsync.whenOrNull(
          data: (_) => service?.isSubscribedToList(widget.listId),
        ) ??
        false;

    return DiVineAppBarAction(
      icon: SvgIconSource(
        isSubscribed
            ? DivineIconName.check.assetPath
            : DivineIconName.plus.assetPath,
      ),
      backgroundColor: isSubscribed
          ? VineTheme.iconButtonBackground
          : VineTheme.vineGreen,
      iconColor: isSubscribed ? VineTheme.vineGreen : VineTheme.whiteText,
      onPressed: _isTogglingSubscription ? null : _toggleSubscription,
      tooltip: isSubscribed ? 'Subscribed' : 'Subscribe',
    );
  }

  Future<void> _toggleSubscription() async {
    setState(() {
      _isTogglingSubscription = true;
    });

    try {
      final service = ref.read(curatedListsStateProvider.notifier).service;
      final isSubscribed = service?.isSubscribedToList(widget.listId) ?? false;

      if (isSubscribed) {
        await service?.unsubscribeFromList(widget.listId);
        Log.info(
          'Unsubscribed from list: ${widget.listName}',
          category: LogCategory.ui,
        );
      } else {
        // Create a CuratedList object for subscribing
        final now = DateTime.now();
        final list = CuratedList(
          id: widget.listId,
          name: widget.listName,
          videoEventIds: widget.videoIds ?? [],
          pubkey: widget.authorPubkey,
          createdAt: now,
          updatedAt: now,
        );
        await service?.subscribeToList(widget.listId, list);
        Log.info(
          'Subscribed to list: ${widget.listName}',
          category: LogCategory.ui,
        );
      }

      // Invalidate providers so Lists tab updates
      ref.invalidate(curatedListsProvider);

      // Trigger rebuild to update button state
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      Log.error('Failed to toggle subscription: $e', category: LogCategory.ui);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.discoverListsFailedToUpdateSubscription('$e'),
            ),
            backgroundColor: VineTheme.likeRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingSubscription = false;
        });
      }
    }
  }
}
