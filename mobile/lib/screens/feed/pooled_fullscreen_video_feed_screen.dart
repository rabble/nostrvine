// ABOUTME: Fullscreen video feed using pooled_video_player package
// ABOUTME: Displays videos with swipe navigation using managed player pool

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/providers/profile_reposts_provider.dart';
import 'package:openvine/screens/fullscreen_video_feed_screen.dart';
import 'package:openvine/widgets/share_video_menu.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

/// Arguments for navigating to PooledFullscreenVideoFeedScreen
class PooledFullscreenVideoFeedArgs {
  const PooledFullscreenVideoFeedArgs({
    required this.source,
    required this.initialIndex,
    this.contextTitle,
  });

  final VideoFeedSource source;
  final int initialIndex;
  final String? contextTitle;
}

/// Fullscreen video feed screen using pooled_video_player.
///
/// This screen is pushed outside the shell route so it doesn't show
/// the bottom navigation bar. It provides a fullscreen video viewing
/// experience with swipe up/down navigation using the managed player pool.
class PooledFullscreenVideoFeedScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'pooled-video-feed';

  /// Path for this route.
  static const path = '/pooled-video-feed';

  const PooledFullscreenVideoFeedScreen({
    required this.source,
    required this.initialIndex,
    this.contextTitle,
    super.key,
  });

  final VideoFeedSource source;
  final int initialIndex;
  final String? contextTitle;

  @override
  ConsumerState<PooledFullscreenVideoFeedScreen> createState() =>
      _PooledFullscreenVideoFeedScreenState();
}

class _PooledFullscreenVideoFeedScreenState
    extends ConsumerState<PooledFullscreenVideoFeedScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  List<VideoEvent> _getVideos() {
    final source = widget.source;
    switch (source) {
      case ProfileFeedSource(:final userId):
        final feedState = ref.watch(profileFeedProvider(userId));
        return feedState.asData?.value.videos ?? [];
      case ProfileRepostsFeedSource(:final userId):
        final repostsState = ref.watch(profileRepostsProvider(userId));
        return repostsState.asData?.value ?? [];
      case LikedVideosFeedSource(:final videos):
        return videos;
      case StaticFeedSource(:final videos):
        return videos;
    }
  }

  void _loadMore() {
    final source = widget.source;
    switch (source) {
      case ProfileFeedSource(:final userId):
        ref.read(profileFeedProvider(userId).notifier).loadMore();
      case ProfileRepostsFeedSource(:final userId):
        ref.read(profileFeedProvider(userId).notifier).loadMore();
      case LikedVideosFeedSource():
        break;
      case StaticFeedSource(:final onLoadMore):
        onLoadMore?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final videos = _getVideos();

    if (videos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: const _FullscreenAppBar(),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final initialIndex = widget.initialIndex.clamp(0, videos.length - 1);

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

    final currentVideo = _currentIndex >= 0 && _currentIndex < videos.length
        ? videos[_currentIndex]
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _FullscreenAppBar(currentVideo: currentVideo),
      body: PooledVideoFeed(
        videos: pooledVideos,
        initialIndex: initialIndex,
        onActiveVideoChanged: (video, index) {
          setState(() => _currentIndex = index);
        },
        onNearEnd: (_) => _loadMore(),
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
  }
}

class _FullscreenAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _FullscreenAppBar({this.currentVideo});

  final VideoEvent? currentVideo;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 72,
      leadingWidth: 80,
      forceMaterialTransparency: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: _BackButton(onPressed: context.pop),
      actions: currentVideo != null
          ? [_EditButton(video: currentVideo!)]
          : null,
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: Container(
        width: 48,
        height: 48,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: SvgPicture.asset(
          'assets/icon/CaretLeft.svg',
          width: 32,
          height: 32,
          colorFilter: const ColorFilter.mode(Colors.blue, BlendMode.srcIn),
          semanticsLabel: 'Close video player',
        ),
      ),
      onPressed: onPressed,
    );
  }
}

class _EditButton extends ConsumerWidget {
  const _EditButton({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featureFlagService = ref.watch(featureFlagServiceProvider);
    final isEditorEnabled = featureFlagService.isEnabled(
      FeatureFlag.enableVideoEditorV1,
    );

    if (!isEditorEnabled) {
      return const SizedBox.shrink();
    }

    final authService = ref.watch(authServiceProvider);
    final currentUserPubkey = authService.currentPublicKeyHex;
    final isOwnVideo =
        currentUserPubkey != null && currentUserPubkey == video.pubkey;

    if (!isOwnVideo) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: SvgPicture.asset(
            'assets/icon/content-controls/pencil.svg',
            width: 32,
            height: 32,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
        onPressed: () => showEditDialogForVideo(context, video),
        tooltip: 'Edit video',
      ),
    );
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
    if (thumbnailUrl == null) {
      return const _LoadingIndicator();
    }

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
