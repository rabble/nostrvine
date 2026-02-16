// ABOUTME: Grid widget displaying user's videos on profile page
// ABOUTME: Shows 3-column grid with thumbnails, handles empty state and navigation

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/mixins/grid_prefetch_mixin.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/screens/fullscreen_video_feed_screen.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Internal class that represents a video entry in the grid
/// It can be a video event or an uploading video
sealed class _GridVideoEntry {}

class _GridVideoEventEntry extends _GridVideoEntry {
  _GridVideoEventEntry(this.videoEvent);

  final VideoEvent videoEvent;
}

class _GridUploadingVideoEntry extends _GridVideoEntry {
  _GridUploadingVideoEntry(this.backgroundUpload);

  final BackgroundUpload backgroundUpload;
}

/// Grid widget displaying user's videos on their profile
class ProfileVideosGrid extends ConsumerStatefulWidget {
  const ProfileVideosGrid({
    required this.videos,
    required this.userIdHex,
    this.isLoading = false,
    this.errorMessage,
    super.key,
  });

  final List<VideoEvent> videos;
  final String userIdHex;

  /// Whether videos are currently being loaded.
  final bool isLoading;

  /// Error message if video loading failed.
  final String? errorMessage;

  @override
  ConsumerState<ProfileVideosGrid> createState() => _ProfileVideosGridState();
}

class _ProfileVideosGridState extends ConsumerState<ProfileVideosGrid>
    with GridPrefetchMixin {
  List<VideoEvent>? _lastPrefetchedVideos;

  @override
  void initState() {
    super.initState();
    // Prefetch visible grid videos after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _prefetchIfNeeded();
      }
    });
  }

  @override
  void didUpdateWidget(ProfileVideosGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Prefetch when video list changes
    if (oldWidget.videos != widget.videos) {
      _prefetchIfNeeded();
    }
  }

  void _prefetchIfNeeded() {
    final videos = widget.videos;
    if (videos.isEmpty || videos == _lastPrefetchedVideos) return;
    _lastPrefetchedVideos = videos;
    prefetchGridVideos(videos);
  }

  void _onVideoTapped(int index) {
    final videos = widget.videos;
    Log.info(
      '🎯 ProfileVideosGrid TAP: gridIndex=$index, '
      'videoId=${videos[index].id}',
      category: LogCategory.video,
    );

    // Pre-warm adjacent videos before navigation
    prefetchAroundIndex(index, videos);

    context.push(
      FullscreenVideoFeedScreen.path,
      extra: FullscreenVideoFeedArgs(
        source: ProfileFeedSource(widget.userIdHex),
        initialIndex: index,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundPublish = context.watch<BackgroundPublishBloc>();
    final isOwnProfile =
        ref.read(authServiceProvider).currentPublicKeyHex == widget.userIdHex;

    final allVideos = [
      // Only show uploading tiles on own profile
      if (isOwnProfile)
        ...backgroundPublish.state.uploads
            .where((upload) => upload.result == null)
            .map(_GridUploadingVideoEntry.new),

      ...widget.videos.map(_GridVideoEventEntry.new),
    ];

    if (widget.errorMessage != null && allVideos.isEmpty) {
      return _ProfileVideosErrorState(errorMessage: widget.errorMessage!);
    }

    if (allVideos.isEmpty) {
      if (widget.isLoading) {
        return const _ProfileVideosLoadingState();
      }
      return _ProfileVideosEmptyState(
        userIdHex: widget.userIdHex,
        isOwnProfile:
            ref.read(authServiceProvider).currentPublicKeyHex ==
            widget.userIdHex,
        onRefresh: () =>
            ref.read(profileFeedProvider(widget.userIdHex).notifier).loadMore(),
      );
    }

    // Count uploading videos to offset indices for published videos
    final uploadingCount = backgroundPublish.state.uploads
        .where((upload) => upload.result == null)
        .length;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(4),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final videoEntry = allVideos[index];
              return switch (videoEntry) {
                _GridUploadingVideoEntry uploadEntry => _VideoGridUploadingTile(
                  backgroundUpload: uploadEntry.backgroundUpload,
                ),
                _GridVideoEventEntry eventEntry => _VideoGridTile(
                  videoEvent: eventEntry.videoEvent,
                  userIdHex: widget.userIdHex,
                  index: index,
                  onTap: () {
                    // Adjust index to account for uploading videos at the top
                    final publishedIndex = index - uploadingCount;
                    if (publishedIndex >= 0) {
                      _onVideoTapped(publishedIndex);
                    }
                  },
                ),
              };
            }, childCount: allVideos.length),
          ),
        ),
      ],
    );
  }
}

/// Empty state shown when user has no videos
class _ProfileVideosEmptyState extends StatelessWidget {
  const _ProfileVideosEmptyState({
    required this.userIdHex,
    required this.isOwnProfile,
    required this.onRefresh,
  });

  final String userIdHex;
  final bool isOwnProfile;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_outlined, color: Colors.grey, size: 64),
              const SizedBox(height: 16),
              const Text(
                'No Videos Yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isOwnProfile
                    ? 'Share your first video to see it here'
                    : "This user hasn't shared any videos yet",
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 32),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(
                  Icons.refresh,
                  color: VineTheme.vineGreen,
                  size: 28,
                ),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _VideoGridUploadingTile extends StatelessWidget {
  const _VideoGridUploadingTile({required this.backgroundUpload});

  final BackgroundUpload backgroundUpload;

  @override
  Widget build(BuildContext context) {
    final thumbnailPath =
        backgroundUpload.draft.clips.firstOrNull?.thumbnailPath;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnailPath != null)
            Image.file(
              File(thumbnailPath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _ThumbnailPlaceholder(),
            )
          else
            const _ThumbnailPlaceholder(),
          const ColoredBox(color: Color(0x66000000)),
          Center(
            child: PartialCircleSpinner(progress: backgroundUpload.progress),
          ),
        ],
      ),
    );
  }
}

/// Individual video tile in the grid
class _VideoGridTile extends StatelessWidget {
  const _VideoGridTile({
    required this.videoEvent,
    required this.userIdHex,
    required this.index,
    required this.onTap,
  });

  final VideoEvent videoEvent;
  final String userIdHex;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: DecoratedBox(
        decoration: BoxDecoration(color: VineTheme.cardBackground),
        child: _VideoThumbnail(thumbnailUrl: videoEvent.thumbnailUrl),
      ),
    ),
  );
}

/// Video thumbnail with loading and error states
class _VideoThumbnail extends StatelessWidget {
  const _VideoThumbnail({required this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: thumbnailUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => const _ThumbnailPlaceholder(),
        errorWidget: (context, url, error) => const _ThumbnailPlaceholder(),
      );
    }
    return const _ThumbnailPlaceholder();
  }
}

/// Loading state shown while videos are being fetched.
class _ProfileVideosLoadingState extends StatelessWidget {
  const _ProfileVideosLoadingState();

  @override
  Widget build(BuildContext context) => const CustomScrollView(
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: VineTheme.vineGreen),
              SizedBox(height: 16),
              Text(
                'Loading videos...',
                style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Error state shown when video loading fails.
class _ProfileVideosErrorState extends StatelessWidget {
  const _ProfileVideosErrorState({required this.errorMessage});

  final String errorMessage;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: VineTheme.secondaryText,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Error: $errorMessage',
                style: const TextStyle(
                  color: VineTheme.primaryText,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Flat color placeholder for thumbnails
class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(4),
      color: VineTheme.surfaceContainer,
    ),
  );
}
