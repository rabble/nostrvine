// ABOUTME: Fullscreen video feed using pooled_video_player package
// ABOUTME: Displays videos with swipe navigation using managed player pool
// ABOUTME: Uses FullscreenFeedBloc for state management

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/share_video_menu.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

/// Arguments for navigating to PooledFullscreenVideoFeedScreen.
///
/// Uses a stream-based approach where the source BLoC/provider remains
/// the single source of truth. The fullscreen screen receives:
/// - A stream of videos for reactive updates
/// - A callback to trigger load more on the source
class PooledFullscreenVideoFeedArgs {
  const PooledFullscreenVideoFeedArgs({
    required this.videosStream,
    required this.initialIndex,
    this.onLoadMore,
    this.contextTitle,
  });

  /// Stream of videos from the source (BLoC or provider).
  final Stream<List<VideoEvent>> videosStream;

  /// Initial video index to start playback.
  final int initialIndex;

  /// Callback to trigger pagination on the source.
  final VoidCallback? onLoadMore;

  /// Optional title for context display.
  final String? contextTitle;
}

/// Fullscreen video feed screen using pooled_video_player.
///
/// This screen is pushed outside the shell route so it doesn't show
/// the bottom navigation bar. It provides a fullscreen video viewing
/// experience with swipe up/down navigation using the managed player pool.
///
/// Uses [FullscreenFeedBloc] for state management, receiving videos from
/// the source via a stream and delegating pagination back to the source.
class PooledFullscreenVideoFeedScreen extends ConsumerWidget {
  /// Route name for this screen.
  static const routeName = 'pooled-video-feed';

  /// Path for this route.
  static const path = '/pooled-video-feed';

  const PooledFullscreenVideoFeedScreen({
    required this.videosStream,
    required this.initialIndex,
    this.onLoadMore,
    this.contextTitle,
    super.key,
  });

  final Stream<List<VideoEvent>> videosStream;
  final int initialIndex;
  final VoidCallback? onLoadMore;
  final String? contextTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaCache = ref.read(mediaCacheProvider);
    final blossomAuthService = ref.read(blossomAuthServiceProvider);

    return BlocProvider(
      create: (_) => FullscreenFeedBloc(
        videosStream: videosStream,
        initialIndex: initialIndex,
        onLoadMore: onLoadMore,
        mediaCache: mediaCache,
        blossomAuthService: blossomAuthService,
      )..add(const FullscreenFeedStarted()),
      child: FullscreenFeedContent(contextTitle: contextTitle),
    );
  }
}

/// Content widget for the fullscreen video feed.
///
/// Manages the [VideoFeedController] lifecycle and wires hooks to dispatch
/// BLoC events for caching and loop enforcement.
@visibleForTesting
class FullscreenFeedContent extends StatefulWidget {
  /// Creates fullscreen feed content.
  @visibleForTesting
  const FullscreenFeedContent({this.contextTitle, super.key});

  /// Optional title for context display.
  final String? contextTitle;

  @override
  State<FullscreenFeedContent> createState() => _FullscreenFeedContentState();
}

class _FullscreenFeedContentState extends State<FullscreenFeedContent> {
  VideoFeedController? _controller;
  List<VideoItem>? _lastPooledVideos;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Creates a VideoFeedController with hooks wired to dispatch BLoC events.
  VideoFeedController _createController(
    List<VideoItem> videos,
    int initialIndex,
  ) {
    return VideoFeedController(
      videos: videos,
      pool: PlayerPool.instance,
      // Hook: Dispatch event for background caching when video is ready
      onVideoReady: (index, player) {
        if (!mounted) return;
        context.read<FullscreenFeedBloc>().add(
          FullscreenFeedVideoCacheStarted(index: index),
        );
      },
      // Hook: Dispatch position updates for loop enforcement
      positionCallback: (index, position) {
        if (!mounted) return;
        context.read<FullscreenFeedBloc>().add(
          FullscreenFeedPositionUpdated(index: index, position: position),
        );
      },
      positionCallbackInterval: const Duration(milliseconds: 100),
    );
  }

  void _handleSeekCommand(SeekCommand command) {
    final controller = _controller;
    if (controller == null) return;

    controller.seek(command.position);
    context.read<FullscreenFeedBloc>().add(
      const FullscreenFeedSeekCommandHandled(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FullscreenFeedBloc, FullscreenFeedState>(
      listenWhen: (prev, curr) =>
          curr.seekCommand != null && prev.seekCommand != curr.seekCommand,
      listener: (context, state) {
        final command = state.seekCommand;
        if (command != null) {
          _handleSeekCommand(command);
        }
      },
      builder: (context, state) {
        if (state.status == FullscreenFeedStatus.initial || !state.hasVideos) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: const _FullscreenAppBar(),
            body: const Center(child: BrandedLoadingIndicator(size: 60)),
          );
        }

        final videos = state.videos;
        final pooledVideos = videos
            .where((v) => v.videoUrl != null)
            .map((e) => VideoItem(id: e.id, url: e.videoUrl!))
            .toList();

        if (pooledVideos.isEmpty) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: const _FullscreenAppBar(),
            body: const Center(
              child: Text(
                'No videos available',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        // Create controller on first valid videos, or add new videos
        if (_controller == null) {
          _controller = _createController(pooledVideos, state.currentIndex);
          _lastPooledVideos = pooledVideos;
        } else if (_lastPooledVideos != null) {
          // Add any new videos that weren't in the previous list
          final newVideos = pooledVideos
              .where((v) => !_lastPooledVideos!.any((old) => old.id == v.id))
              .toList();
          if (newVideos.isNotEmpty) {
            _controller!.addVideos(newVideos);
          }
          _lastPooledVideos = pooledVideos;
        }

        return Scaffold(
          backgroundColor: Colors.black,
          extendBodyBehindAppBar: true,
          appBar: _FullscreenAppBar(currentVideo: state.currentVideo),
          body: PooledVideoFeed(
            videos: pooledVideos,
            controller: _controller,
            initialIndex: state.currentIndex,
            onActiveVideoChanged: (video, index) {
              context.read<FullscreenFeedBloc>().add(
                FullscreenFeedIndexChanged(index),
              );
            },
            onNearEnd: (_) {
              context.read<FullscreenFeedBloc>().add(
                const FullscreenFeedLoadMoreRequested(),
              );
            },
            nearEndThreshold: 2,
            itemBuilder: (context, video, index, {required isActive}) {
              final originalEvent = videos[index];
              return _PooledFullscreenItem(
                video: originalEvent,
                index: index,
                isActive: isActive,
                contextTitle: widget.contextTitle,
              );
            },
          ),
        );
      },
    );
  }
}

class _FullscreenAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _FullscreenAppBar({this.currentVideo});

  final VideoEvent? currentVideo;

  static const _style = DiVineAppBarStyle(
    iconButtonBackgroundColor: Color(0x4D000000), // black with 0.3 alpha
  );

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DiVineAppBar(
      titleWidget: const SizedBox.shrink(),
      showBackButton: true,
      onBackPressed: context.pop,
      backgroundMode: DiVineAppBarBackgroundMode.transparent,
      style: _style,
      actions: _buildEditAction(context, ref),
    );
  }

  // TODO(any) : update to use bloc instead of riverpod
  List<DiVineAppBarAction> _buildEditAction(
    BuildContext context,
    WidgetRef ref,
  ) {
    final video = currentVideo;
    if (video == null) return const [];

    final featureFlagService = ref.watch(featureFlagServiceProvider);
    final isEditorEnabled = featureFlagService.isEnabled(
      FeatureFlag.enableVideoEditorV1,
    );
    if (!isEditorEnabled) return const [];

    final authService = ref.watch(authServiceProvider);
    final currentUserPubkey = authService.currentPublicKeyHex;
    final isOwnVideo =
        currentUserPubkey != null && currentUserPubkey == video.pubkey;
    if (!isOwnVideo) return const [];

    return [
      DiVineAppBarAction(
        icon: const SvgIconSource('assets/icon/content-controls/pencil.svg'),
        onPressed: () => showEditDialogForVideo(context, video),
        tooltip: 'Edit video',
        semanticLabel: 'Edit video',
      ),
    ];
  }
}

class _PooledFullscreenItem extends ConsumerWidget {
  const _PooledFullscreenItem({
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
      child: _PooledFullscreenItemContent(
        video: video,
        index: index,
        isActive: isActive,
        contextTitle: contextTitle,
      ),
    );
  }
}

class _PooledFullscreenItemContent extends StatelessWidget {
  const _PooledFullscreenItemContent({
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
    final isPortrait = video.dimensions != null ? video.isPortrait : true;

    return ColoredBox(
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
            VideoOverlayActions(
              video: video,
              isVisible: isActive,
              isActive: isActive,
              hasBottomNavigation: false,
              contextTitle: contextTitle,
              isFullscreen: true,
            ),
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
    final boxFit = isPortrait ? BoxFit.cover : BoxFit.contain;
    final url = thumbnailUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail background (if available)
        if (url != null && url.isNotEmpty)
          Image.network(
            url,
            fit: boxFit,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
          )
        else
          const ColoredBox(color: Colors.black),
        // Loading indicator overlay
        const _LoadingIndicator(),
      ],
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(child: BrandedLoadingIndicator(size: 60));
  }
}
