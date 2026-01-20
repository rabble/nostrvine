import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:pooled_video_player/pooled_video_player.dart';
import 'package:video_player/video_player.dart';

class VideoFeedPage extends ConsumerWidget {
  static const String path = '/new-video-feed';

  static const String routeName = 'new-video-feed';

  const VideoFeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosRepository = ref.read(videosRepositoryProvider);
    final followRepository = ref.read(followRepositoryProvider);

    return BlocProvider(
      create: (_) => VideoFeedBloc(
        videosRepository: videosRepository,
        followRepository: followRepository,
      )..add(const VideoFeedStarted(mode: FeedMode.latest)),
      child: const _VideoFeedView(),
    );
  }
}

class _VideoFeedView extends ConsumerStatefulWidget {
  const _VideoFeedView();

  @override
  ConsumerState<_VideoFeedView> createState() => _VideoFeedViewState();
}

class _VideoFeedViewState extends ConsumerState<_VideoFeedView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: BlocBuilder<VideoFeedBloc, VideoFeedState>(
          buildWhen: (prev, curr) => prev.mode != curr.mode,
          builder: (context, state) => Text(
            state.mode.name.toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        actions: [
          _FeedModeSwitch(),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              context.read<VideoFeedBloc>().add(
                const VideoFeedRefreshRequested(),
              );
            },
          ),
        ],
      ),
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

          // Filter out videos without URLs and wrap for pool compatibility
          final pooledVideos = state.videos
              .where((v) => v.videoUrl != null)
              .map(_PooledVideoEventAdapter.new)
              .toList();

          // Note: RefreshIndicator removed - it conflicts with PageView
          // scrolling and adds memory overhead. Use the refresh button instead.
          return Stack(
            children: [
              PooledVideoFeed(
                videos: pooledVideos,
                feedContext: 'video_feed_${state.mode.name}',
                // getCachedFile: openVineVideoCache.getCachedVideoSync,
                itemBuilder: (context, video, index, isActive) {
                  final adapter = video as _PooledVideoEventAdapter;
                  return _PooledVideoFeedItem(
                    video: adapter.event,
                    index: index,
                    isActive: isActive,
                    contextTitle: 'BLoC Test (${state.mode.name})',
                  );
                },
                onActiveVideoChanged: (video, index) {
                  // Trigger pagination when near end
                  if (state.hasMore && index >= pooledVideos.length - 2) {
                    context.read<VideoFeedBloc>().add(
                      const VideoFeedLoadMoreRequested(),
                    );
                  }
                },
              ),
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
              // Debug info overlay
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Videos: ${pooledVideos.length} | '
                    'HasMore: ${state.hasMore}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
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

class _FeedModeSwitch extends StatelessWidget {
  const _FeedModeSwitch();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VideoFeedBloc, VideoFeedState>(
      buildWhen: (prev, curr) => prev.mode != curr.mode,
      builder: (context, state) => IconButton(
        icon: const Icon(Icons.filter_list, color: Colors.white),
        onPressed: () => _showFeedModeBottomSheet(context, state.mode),
      ),
    );
  }

  Future<void> _showFeedModeBottomSheet(
    BuildContext context,
    FeedMode currentMode,
  ) async {
    final selected = await VineBottomSheetSelectionMenu.show(
      context: context,
      selectedValue: currentMode.name,
      options: const [
        VineBottomSheetSelectionOptionData(label: 'New', value: 'latest'),
        VineBottomSheetSelectionOptionData(label: 'Popular', value: 'popular'),
        VineBottomSheetSelectionOptionData(label: 'Following', value: 'home'),
      ],
    );

    if (selected != null && context.mounted) {
      final mode = FeedMode.values.firstWhere((m) => m.name == selected);
      context.read<VideoFeedBloc>().add(VideoFeedModeChanged(mode));
    }
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

/// Adapter that wraps [VideoEvent] to implement [PooledVideo] interface.
///
/// This allows VideoEvent to be used with the pooled_video_player package
/// without modifying the models package or adding dependencies to it.
class _PooledVideoEventAdapter implements PooledVideo {
  const _PooledVideoEventAdapter(this.event);

  /// The wrapped video event.
  final VideoEvent event;

  @override
  String get id => event.id;

  @override
  String get videoUrl => event.videoUrl!; // Safe: filtered before wrapping

  @override
  String? get thumbnailUrl => event.thumbnailUrl;
}

/// A video feed item that uses [PooledVideoPlayer] for playback.
///
/// This widget renders video content with automatic controller management
/// from the pool, plus the full overlay UI with author info, actions, etc.
class _PooledVideoFeedItem extends ConsumerStatefulWidget {
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
  ConsumerState<_PooledVideoFeedItem> createState() =>
      _PooledVideoFeedItemState();
}

class _PooledVideoFeedItemState extends ConsumerState<_PooledVideoFeedItem> {
  late final VideoInteractionsBloc _interactionsBloc;

  @override
  void initState() {
    super.initState();
    _createInteractionsBloc();
  }

  void _createInteractionsBloc() {
    final likesRepository = ref.read(likesRepositoryProvider);
    final commentsRepository = ref.read(commentsRepositoryProvider);

    _interactionsBloc = VideoInteractionsBloc(
      eventId: widget.video.id,
      authorPubkey: widget.video.pubkey,
      likesRepository: likesRepository,
      commentsRepository: commentsRepository,
    );
    _interactionsBloc.add(const VideoInteractionsSubscriptionRequested());
    _interactionsBloc.add(const VideoInteractionsFetchRequested());
  }

  @override
  void dispose() {
    _interactionsBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: PooledVideoPlayer(
        video: _PooledVideoEventAdapter(widget.video),
        autoPlay: widget.isActive,
        enableTapToPause: widget.isActive,
        videoBuilder: (context, controller) => _buildVideoWidget(controller),
        loadingBuilder: (context) => _buildLoadingPlaceholder(),
        overlayBuilder: (context, controller) =>
            BlocProvider<VideoInteractionsBloc>.value(
              value: _interactionsBloc,
              child: VideoOverlayActions(
                video: widget.video,
                isVisible: widget.isActive,
                isActive: widget.isActive,
                hasBottomNavigation: false,
                contextTitle: widget.contextTitle,
              ),
            ),
        onVideoError: (error) {
          debugPrint('Video error for ${widget.video.id}: $error');
        },
      ),
    );
  }

  Widget _buildVideoWidget(VideoPlayerController controller) {
    final videoWidth = controller.value.size.width > 0
        ? controller.value.size.width
        : 1.0;
    final videoHeight = controller.value.size.height > 0
        ? controller.value.size.height
        : 1.0;

    return FittedBox(
      fit: BoxFit.contain,
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: videoWidth,
        height: videoHeight,
        child: VideoPlayer(controller),
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Center(
      child: widget.video.thumbnailUrl != null
          ? Image.network(
              widget.video.thumbnailUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _LoadingIndicator(),
            )
          : const _LoadingIndicator(),
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
