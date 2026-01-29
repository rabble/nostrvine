// ABOUTME: Screen displaying videos filtered by a specific hashtag
// ABOUTME: Allows users to explore all videos with a particular hashtag

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';

class HashtagFeedScreen extends ConsumerStatefulWidget {
  const HashtagFeedScreen({
    required this.hashtag,
    this.embedded = false,
    this.onVideoTap,
    super.key,
  });
  final String hashtag;
  // If true, don't show Scaffold/AppBar (for embedding in explore)
  final bool embedded;
  // Callback for video navigation when embedded
  final void Function(List<VideoEvent> videos, int index)? onVideoTap;

  @override
  ConsumerState<HashtagFeedScreen> createState() => _HashtagFeedScreenState();
}

class _HashtagFeedScreenState extends ConsumerState<HashtagFeedScreen> {
  /// Tracks whether we've completed the initial subscription attempt.
  /// Used to show loading state until subscription has been tried.
  bool _subscriptionAttempted = false;

  @override
  void initState() {
    super.initState();
    // Subscribe to videos with this hashtag
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // Safety check: don't use ref if widget is disposed

      print('[HASHTAG] 🏷️  Subscribing to hashtag: ${widget.hashtag}');
      final hashtagService = ref.read(hashtagServiceProvider);
      hashtagService
          .subscribeToHashtagVideos([widget.hashtag])
          .then((_) {
            if (!mounted) return; // Safety check before async callback
            print(
              '[HASHTAG] ✅ Successfully subscribed to hashtag: ${widget.hashtag}',
            );
            setState(() => _subscriptionAttempted = true);
          })
          .catchError((error) {
            if (!mounted) return; // Safety check before async callback
            print(
              '[HASHTAG] ❌ Failed to subscribe to hashtag ${widget.hashtag}: $error',
            );
            setState(() => _subscriptionAttempted = true);
          });
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = Builder(
      builder: (context) {
        print('[HASHTAG] 🔄 Building HashtagFeedScreen for #${widget.hashtag}');
        final videoService = ref.watch(videoEventServiceProvider);
        final hashtagService = ref.watch(hashtagServiceProvider);
        final videos = List<VideoEvent>.from(
          hashtagService.getVideosByHashtags([widget.hashtag]),
        )..sort(VideoEvent.compareByLoopsThenTime);

        print(
          '[HASHTAG] 📊 Found ${videos.length} videos for #${widget.hashtag}',
        );
        if (videos.isNotEmpty) {
          print(
            '[HASHTAG] 📹 First 3 video IDs: ${videos.take(3).map((v) => v.id).join(', ')}',
          );
        }

        // Use per-subscription loading state for hashtag feed
        final isLoadingHashtag = videoService.isLoadingForSubscription(
          SubscriptionType.hashtag,
        );
        print(
          '[HASHTAG] ⏳ Loading state: $isLoadingHashtag, subscription attempted: $_subscriptionAttempted',
        );

        // Check if we have videos in different lists
        final discoveryCount = videoService.getEventCount(
          SubscriptionType.discovery,
        );
        final hashtagCount = videoService.getEventCount(
          SubscriptionType.hashtag,
        );
        print(
          '[HASHTAG] 📊 Discovery videos: $discoveryCount, Hashtag videos: $hashtagCount',
        );

        // Show loading if:
        // 1. We haven't attempted subscription yet (initial state), OR
        // 2. Subscription is actively loading
        final shouldShowLoading = !_subscriptionAttempted || isLoadingHashtag;

        if (shouldShowLoading && videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: VineTheme.vineGreen),
                const SizedBox(height: 24),
                Text(
                  'Loading videos about #${widget.hashtag}...',
                  style: const TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This may take a few moments',
                  style: TextStyle(
                    color: VineTheme.secondaryText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        if (videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.tag, size: 64, color: VineTheme.secondaryText),
                const SizedBox(height: 16),
                Text(
                  'No videos found for #${widget.hashtag}',
                  style: const TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Be the first to post a video with this hashtag!',
                  style: TextStyle(
                    color: VineTheme.secondaryText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        // Use grid view when embedded (in explore), full-screen list when standalone
        if (widget.embedded) {
          return ComposableVideoGrid(
            videos: videos,
            onVideoTap:
                widget.onVideoTap ??
                (videos, index) {
                  // Default behavior: navigate to hashtag feed mode using GoRouter
                  context.go(
                    HashtagScreenRouter.pathForTag(
                      widget.hashtag,
                      index: index,
                    ),
                  );
                },
            onRefresh: () async {
              Log.info(
                '🔄 HashtagFeedScreen: Refreshing hashtag #${widget.hashtag}',
                category: LogCategory.video,
              );
              // Fetch fresh data from REST API (force bypasses 5-min cache)
              final analyticsService = ref.read(analyticsApiServiceProvider);
              final funnelcakeAvailable =
                  ref.read(funnelcakeAvailableProvider).asData?.value ?? false;
              if (funnelcakeAvailable) {
                await analyticsService.getVideosByHashtag(
                  hashtag: widget.hashtag,
                  forceRefresh: true,
                );
              }
              // Resubscribe to hashtag to fetch fresh WebSocket data
              await hashtagService.subscribeToHashtagVideos([widget.hashtag]);
            },
          );
        }

        // Standalone mode: full-screen scrollable list
        final isLoadingMore = isLoadingHashtag;

        return RefreshIndicator(
          semanticsLabel: 'searching for more videos',
          color: VineTheme.onPrimary,
          backgroundColor: VineTheme.vineGreen,
          onRefresh: () async {
            Log.info(
              '🔄 HashtagFeedScreen: Refreshing hashtag #${widget.hashtag}',
              category: LogCategory.video,
            );
            // Fetch fresh data from REST API (force bypasses 5-min cache)
            final analyticsService = ref.read(analyticsApiServiceProvider);
            final funnelcakeAvailable =
                ref.read(funnelcakeAvailableProvider).asData?.value ?? false;
            if (funnelcakeAvailable) {
              await analyticsService.getVideosByHashtag(
                hashtag: widget.hashtag,
                forceRefresh: true,
              );
            }
            // Resubscribe to hashtag to fetch fresh WebSocket data
            await hashtagService.subscribeToHashtagVideos([widget.hashtag]);
          },
          child: ListView.builder(
            // Add 1 for loading indicator if still loading
            itemCount: videos.length + (isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              // Show loading indicator as last item
              if (index == videos.length) {
                return Container(
                  height: MediaQuery.of(context).size.height,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        color: VineTheme.vineGreen,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Getting more videos about #${widget.hashtag}...',
                        style: const TextStyle(
                          color: VineTheme.primaryText,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please wait while we fetch from relays',
                        style: TextStyle(
                          color: VineTheme.secondaryText,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final video = videos[index];
              return GestureDetector(
                onTap: () {
                  // Navigate to hashtag feed mode using GoRouter
                  context.go(
                    HashtagScreenRouter.pathForTag(
                      widget.hashtag,
                      index: index,
                    ),
                  );
                },
                child: SizedBox(
                  height: MediaQuery.of(context).size.height,
                  width: double.infinity,
                  child: VideoFeedItem(
                    video: video,
                    index: index,
                    contextTitle: '#${widget.hashtag}',
                    forceShowOverlay: true,
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    // If embedded, return body only; otherwise wrap with Scaffold
    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: VineTheme.vineGreen,
        elevation: 0,
        title: Text(
          '#${widget.hashtag}',
          style: const TextStyle(
            color: VineTheme.whiteText,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: VineTheme.whiteText),
          onPressed: context.pop,
        ),
      ),
      body: body,
    );
  }
}
