import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/feed/feed_mode_switch.dart';
import 'package:openvine/screens/feed/feed_video_overlay.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';
import 'package:openvine/widgets/vine_drawer.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

class VideoFeedPage extends ConsumerWidget {
  static const String path = '/new-video-feed';

  static const String routeName = 'new-video-feed';

  const VideoFeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosRepository = ref.read(videosRepositoryProvider);
    final followRepository = ref.read(followRepositoryProvider);

    // Show loading until NostrClient has keys
    if (followRepository == null) {
      return const BrandedLoadingScaffold();
    }

    return BlocProvider(
      create: (_) => VideoFeedBloc(
        videosRepository: videosRepository,
        followRepository: followRepository,
      )..add(const VideoFeedStarted(mode: FeedMode.latest)),
      child: const VideoFeedView(),
    );
  }
}

@visibleForTesting
class VideoFeedView extends StatefulWidget {
  const VideoFeedView({super.key});

  @override
  State<VideoFeedView> createState() => _VideoFeedViewState();
}

class _VideoFeedViewState extends State<VideoFeedView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      drawer: const VineDrawer(),
      body: BlocBuilder<VideoFeedBloc, VideoFeedState>(
        builder: (context, state) {
          // Loading state (including initial state before first load)
          if (state.isLoading) {
            return const Center(child: BrandedLoadingIndicator(size: 80));
          }

          // Error state
          if (state.status == VideoFeedStatus.failure) {
            return _FeedErrorWidget(error: state.error);
          }

          // Empty state
          if (state.isEmpty) {
            return FeedEmptyWidget(state: state);
          }

          // Wrap videos for pool compatibility
          final pooledVideos = state.videos
              .map((e) => VideoItem(id: e.id, url: e.videoUrl!))
              .toList();

          // Note: RefreshIndicator removed - it conflicts with PageView
          // scrolling and adds memory overhead. Use the refresh button instead.
          return Stack(
            children: [
              PooledVideoFeed(
                videos: pooledVideos,
                itemBuilder: (context, video, index, {required isActive}) {
                  final originalEvent = state.videos[index];
                  return _PooledVideoFeedItem(
                    video: originalEvent,
                    index: index,
                    isActive: isActive,
                    contextTitle: 'BLoC Test (${state.mode.name})',
                  );
                },
                onNearEnd: (index) {
                  // PooledVideoFeed fires this when the user is within
                  // nearEndThreshold (default 3) of the end, using the
                  // controller's actual video count (not the BlocBuilder's
                  // list length, which may differ due to deduplication).
                  if (state.hasMore) {
                    context.read<VideoFeedBloc>().add(
                      const VideoFeedLoadMoreRequested(),
                    );
                  }
                },
              ),
              const FeedModeSwitch(),
              // Loading more indicator
              if (state.isLoadingMore)
                const Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: VineTheme.vineGreen,
                      strokeWidth: 2,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FeedErrorWidget extends StatelessWidget {
  const _FeedErrorWidget({this.error});

  final VideoFeedError? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Failed to load videos',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error.toString(), style: const TextStyle(color: Colors.grey)),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.read<VideoFeedBloc>().add(
              const VideoFeedRefreshRequested(),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class FeedEmptyWidget extends StatelessWidget {
  const FeedEmptyWidget({required this.state, super.key});

  final VideoFeedState state;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.video_library_outlined,
            color: Colors.grey,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            _getEmptyMessage(state),
            style: const TextStyle(color: Colors.white, fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getEmptyMessage(VideoFeedState state) {
    if (state.mode == FeedMode.home &&
        state.error == VideoFeedError.noFollowedUsers) {
      return 'No followed users.\nFollow someone to see their videos here.';
    }
    return 'No videos found for ${state.mode.name} feed.';
  }
}

/// A video feed item that uses [PooledVideoPlayer] for playback.
///
/// This widget renders video content with automatic controller management
/// from the pool, plus the full overlay UI with author info, actions, etc.
class _PooledVideoFeedItem extends ConsumerWidget {
  const _PooledVideoFeedItem({
    required this.video,
    required this.index,
    required this.isActive,
    this.contextTitle,
  });

  final VideoEvent video;
  final int index;
  final bool isActive;
  final String? contextTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likesRepository = ref.read(likesRepositoryProvider);
    final commentsRepository = ref.read(commentsRepositoryProvider);
    final repostsRepository = ref.read(repostsRepositoryProvider);

    // Build addressable ID for reposts if video has a d-tag (vineId)
    final addressableId = video.addressableId;

    return BlocProvider<VideoInteractionsBloc>(
      create: (_) =>
          VideoInteractionsBloc(
              eventId: video.id,
              authorPubkey: video.pubkey,
              likesRepository: likesRepository,
              commentsRepository: commentsRepository,
              repostsRepository: repostsRepository,
              addressableId: addressableId,
            )
            ..add(const VideoInteractionsSubscriptionRequested())
            ..add(const VideoInteractionsFetchRequested()),
      child: _PooledVideoFeedItemContent(
        video: video,
        index: index,
        isActive: isActive,
        contextTitle: contextTitle,
      ),
    );
  }
}

class _PooledVideoFeedItemContent extends StatelessWidget {
  const _PooledVideoFeedItemContent({
    required this.video,
    required this.index,
    required this.isActive,
    this.contextTitle,
  });

  final VideoEvent video;
  final int index;
  final bool isActive;
  final String? contextTitle;

  @override
  Widget build(BuildContext context) {
    // All videos without dimensions are treated as portrait as its default
    // usecase (e.g. Reels-style vertical videos).
    final isPortrait = video.dimensions != null ? video.isPortrait : true;

    return Container(
      color: Colors.black,
      child: PooledVideoPlayer(
        index: index,
        thumbnailUrl: video.thumbnailUrl,
        enableTapToPause: isActive,
        videoBuilder: (context, videoController, player) => _FittedVideoPlayer(
          videoController: videoController,
          isPortrait: isPortrait,
        ),
        loadingBuilder: (context) => _VideoLoadingPlaceholder(
          thumbnailUrl: video.thumbnailUrl,
          isPortrait: isPortrait,
        ),
        overlayBuilder: (context, videoController, player) =>
            FeedVideoOverlay(video: video, isActive: isActive),
      ),
    );
  }
}

class _FittedVideoPlayer extends StatelessWidget {
  const _FittedVideoPlayer({
    required this.videoController,
    this.isPortrait = true,
  });

  final VideoController videoController;
  final bool isPortrait;

  @override
  Widget build(BuildContext context) {
    // Portrait: fill screen (cover), Landscape: fit entirely (contain)
    final boxFit = isPortrait ? BoxFit.cover : BoxFit.contain;

    return Video(
      controller: videoController,
      fit: boxFit,
      filterQuality: FilterQuality.high,
      controls: NoVideoControls,
    );
  }
}

class _VideoLoadingPlaceholder extends StatelessWidget {
  const _VideoLoadingPlaceholder({this.thumbnailUrl, this.isPortrait = true});

  final String? thumbnailUrl;
  final bool isPortrait;

  @override
  Widget build(BuildContext context) {
    if (thumbnailUrl == null) {
      return const _LoadingIndicator();
    }

    // Portrait: fill height, crop sides (cover)
    // Landscape: fit entirely, centered (contain)
    final boxFit = isPortrait ? BoxFit.cover : BoxFit.contain;

    return SizedBox.expand(
      child: Image.network(
        thumbnailUrl!,
        fit: boxFit,
        alignment: Alignment.center,
        errorBuilder: (_, __, ___) => const _LoadingIndicator(),
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: VineTheme.vineGreen),
    );
  }
}
