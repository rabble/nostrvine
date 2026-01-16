// ABOUTME: Screen for displaying videos from a curated NIP-51 kind 30005 list
// ABOUTME: Shows videos in a grid with tap-to-play navigation

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/screens/pure/explore_video_screen_pure.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/video_controller_cleanup.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/user_name.dart';

class CuratedListFeedScreen extends ConsumerStatefulWidget {
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
          ? AppBar(
              backgroundColor: VineTheme.cardBackground,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: VineTheme.whiteText),
                onPressed: context.pop,
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.listName,
                    style: const TextStyle(
                      color: VineTheme.whiteText,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.authorPubkey != null) ...[
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: () =>
                          context.pushProfileGrid(widget.authorPubkey!),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'by ',
                            style: TextStyle(
                              color: VineTheme.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                          Flexible(
                            child: UserName.fromPubKey(
                              widget.authorPubkey!,
                              style: TextStyle(
                                color: VineTheme.vineGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [_buildSubscribeButton()],
            )
          : null,
      body: videosAsync.when(
        data: (videos) {
          if (videos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_library,
                    size: 64,
                    color: VineTheme.secondaryText,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No videos in this list',
                    style: TextStyle(
                      color: VineTheme.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add some videos to get started',
                    style: TextStyle(
                      color: VineTheme.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

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
              CircularProgressIndicator(color: VineTheme.vineGreen),
              const SizedBox(height: 16),
              Text(
                'Loading videos...',
                style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
              ),
            ],
          ),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: VineTheme.likeRed),
              const SizedBox(height: 16),
              Text(
                'Failed to load list',
                style: TextStyle(color: VineTheme.likeRed, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  error.toString(),
                  style: TextStyle(
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
                label: const Text('Retry'),
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
          'No videos available',
          style: TextStyle(color: VineTheme.secondaryText),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(List<VideoEvent> videos) {
    if (videos.isEmpty || _activeVideoIndex! >= videos.length) {
      return Center(
        child: Text(
          'Video not available',
          style: TextStyle(color: VineTheme.secondaryText),
        ),
      );
    }

    // Use Stack with back button overlay to exit video mode
    return Stack(
      children: [
        ExploreVideoScreenPure(
          startingVideo: videos[_activeVideoIndex!],
          videoList: videos,
          contextTitle: widget.listName,
          startingIndex: _activeVideoIndex!,
          useLocalActiveState:
              true, // Use local state since not using URL routing
        ),
        // Back button overlay to exit video mode
        Positioned(
          top: 50,
          left: 16,
          child: SafeArea(
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: VineTheme.whiteText),
              ),
              onPressed: () {
                // Stop all videos before switching to grid
                disposeAllVideoControllers(ref);
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

  Widget _buildSubscribeButton() {
    // Watch the service state for subscription status
    final serviceAsync = ref.watch(curatedListsStateProvider);
    final service = ref.read(curatedListsStateProvider.notifier).service;
    final isSubscribed =
        serviceAsync.whenOrNull(
          data: (_) => service?.isSubscribedToList(widget.listId),
        ) ??
        false;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ElevatedButton.icon(
        onPressed: _isTogglingSubscription ? null : _toggleSubscription,
        icon: _isTogglingSubscription
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isSubscribed
                      ? VineTheme.vineGreen
                      : VineTheme.backgroundColor,
                ),
              )
            : Icon(isSubscribed ? Icons.check : Icons.add, size: 18),
        label: Text(
          isSubscribed ? 'Subscribed' : 'Subscribe',
          style: const TextStyle(fontSize: 12),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSubscribed
              ? VineTheme.cardBackground
              : VineTheme.vineGreen,
          foregroundColor: isSubscribed
              ? VineTheme.vineGreen
              : VineTheme.backgroundColor,
          side: isSubscribed
              ? BorderSide(color: VineTheme.vineGreen, width: 1)
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  Future<void> _toggleSubscription() async {
    setState(() {
      _isTogglingSubscription = true;
    });

    try {
      final service = await ref
          .read(curatedListsStateProvider.notifier)
          .service;
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
            content: Text('Failed to update subscription: $e'),
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
