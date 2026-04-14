// ABOUTME: Grid widget displaying user's videos on profile page
// ABOUTME: Shows 3-column grid with thumbnails, handles empty state and navigation

import 'dart:async';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/grid_prefetch_mixin.dart';
import 'package:openvine/mixins/scroll_pagination_mixin.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/widgets/profile/profile_tab_empty_state.dart';
import 'package:openvine/widgets/profile/profile_tab_error_state.dart';
import 'package:openvine/widgets/profile/profile_tab_loading_more_sliver.dart';
import 'package:openvine/widgets/profile/profile_tab_loading_state.dart';
import 'package:openvine/widgets/profile/profile_tab_thumbnail.dart';
import 'package:openvine/widgets/profile/profile_tab_thumbnail_placeholder.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:rxdart/rxdart.dart';
import 'package:unified_logger/unified_logger.dart';

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
    with GridPrefetchMixin, ScrollPaginationMixin {
  List<VideoEvent>? _lastPrefetchedVideos;
  final _videosStreamController =
      StreamController<List<VideoEvent>>.broadcast();
  final _precachedThumbnailUrls = <String>{};

  /// Resolved from [PrimaryScrollController] provided by [NestedScrollView].
  ScrollController? _primaryScrollController;

  @override
  ScrollController get paginationScrollController => _primaryScrollController!;

  @override
  bool canLoadMore() {
    final feedState = ref
        .read(profileFeedProvider(widget.userIdHex))
        .asData
        ?.value;
    return feedState != null &&
        feedState.hasMoreContent &&
        !feedState.isLoadingMore;
  }

  @override
  FutureOr<void> onLoadMore() => _triggerLoadMore();

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final primary = PrimaryScrollController.of(context);
    if (_primaryScrollController != primary) {
      if (_primaryScrollController != null) disposePagination();
      _primaryScrollController = primary;
      initPagination();
    }
  }

  @override
  void dispose() {
    disposePagination();
    _videosStreamController.close();
    super.dispose();
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

  Future<void> _triggerLoadMore() async {
    await ref.read(profileFeedProvider(widget.userIdHex).notifier).loadMore();
  }

  void _onVideoTapped(int index, {required VoidCallback onLoadMore}) {
    final videos = widget.videos;
    Log.info(
      '🎯 ProfileVideosGrid TAP: gridIndex=$index, '
      'videoId=${videos[index].id}',
      category: LogCategory.video,
    );

    // Pre-warm adjacent videos before navigation
    prefetchAroundIndex(index, videos);

    context.push(
      PooledFullscreenVideoFeedScreen.path,
      extra: PooledFullscreenVideoFeedArgs(
        videosStream: _videosStreamController.stream.startWith(videos),
        initialIndex: index,
        onLoadMore: onLoadMore,
        trafficSource: ViewTrafficSource.profile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Push provider updates to stream for fullscreen feed
    ref.listen(profileFeedProvider(widget.userIdHex), (_, next) {
      next.whenData((feedState) {
        if (!_videosStreamController.isClosed) {
          _videosStreamController.add(feedState.videos);
        }
      });
    });

    final authService = ref.read(authServiceProvider);
    final profileFeedNotifier = ref.read(
      profileFeedProvider(widget.userIdHex).notifier,
    );
    Future<void> loadMoreProfileVideos() => profileFeedNotifier.loadMore();
    final backgroundPublish = context.watch<BackgroundPublishBloc>();
    final isOwnProfile = authService.currentPublicKeyHex == widget.userIdHex;

    // Uploads that are still in progress (no result yet).
    final activeUploads = isOwnProfile
        ? backgroundPublish.state.uploads
              .where((upload) => upload.result == null)
              .toList()
        : <BackgroundUpload>[];

    // De-duplicate relay-delivered videos against active uploads.
    //
    // When a video is published, the relay may deliver it to the profile
    // feed before the [BackgroundPublishBloc] removes the upload from its
    // state. This causes a brief visual duplicate: the upload tile and
    // the published video tile appear side-by-side.
    //
    // To prevent this we filter relay videos by:
    //  1. Only inspecting videos created within the last 5 minutes —
    //     older videos cannot be duplicates of an in-progress upload.
    //  2. Matching by title against the active upload drafts.
    //  3. Removing only the *first* match per title so that legitimate
    //     older videos with the same title are not hidden.
    final now = DateTime.now();
    final matchedTitles = <String>{};
    final filteredVideos = isOwnProfile
        ? widget.videos.where((video) {
            // Step 1: Skip de-duplication for videos older than 5 minutes.
            final videoTime = DateTime.fromMillisecondsSinceEpoch(
              video.createdAt * 1000,
            );
            if (now.difference(videoTime).inMinutes > 5) return true;

            // Step 2: Check if this video's title matches an active upload
            // that hasn't been matched yet.
            final isDuplicate =
                !matchedTitles.contains(video.title) &&
                activeUploads.any(
                  (upload) => upload.draft.title == video.title,
                );

            // Step 3: Mark the title as matched so only the first duplicate
            // per upload is filtered out. Pre-cache the network thumbnail
            // so it's instantly available when the upload tile disappears.
            //
            // NOTE: The [downloadFile] call is intentionally placed here
            // inside build(). It is a fire-and-forget cache warm-up that
            // is guarded by [_precachedThumbnailUrls] so it executes at
            // most once per URL across rebuilds. Moving it to
            // didUpdateWidget would require duplicating the de-duplication
            // logic. This is an acceptable trade-off.
            if (isDuplicate) {
              if (video.title case final title?) {
                matchedTitles.add(title);
              }
              final url = video.thumbnailUrl;
              if (url != null &&
                  url.isNotEmpty &&
                  _precachedThumbnailUrls.add(url)) {
                openVineImageCache.downloadFile(url);
              }
              return false;
            }
            return true;
          }).toList()
        : widget.videos;

    final allVideos = [
      ...activeUploads.map(_GridUploadingVideoEntry.new),
      ...filteredVideos.map(_GridVideoEventEntry.new),
    ];

    if (widget.errorMessage != null && allVideos.isEmpty) {
      return ProfileTabErrorState(message: widget.errorMessage!);
    }

    if (allVideos.isEmpty) {
      if (widget.isLoading) {
        return ProfileTabLoadingState(
          message: context.l10n.profileLoadingVideos,
        );
      }
      return ProfileTabEmptyState(
        icon: DivineIconName.videoCamera,
        title: context.l10n.profileNoVideosTitle,
        subtitle: isOwnProfile
            ? context.l10n.profileNoVideosOwnSubtitle
            : context.l10n.profileNoVideosOtherSubtitle,
        onRefresh: loadMoreProfileVideos,
      );
    }

    // Count uploading videos to offset indices for published videos
    final uploadingCount = activeUploads.length;

    final isLoadingMore =
        ref
            .watch(profileFeedProvider(widget.userIdHex))
            .asData
            ?.value
            .isLoadingMore ??
        false;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: .fromLTRB(
            4,
            4,
            4,
            4 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final videoEntry = allVideos[index];
              return switch (videoEntry) {
                final _GridUploadingVideoEntry uploadEntry =>
                  _VideoGridUploadingTile(
                    backgroundUpload: uploadEntry.backgroundUpload,
                  ),
                final _GridVideoEventEntry eventEntry => _VideoGridTile(
                  videoEvent: eventEntry.videoEvent,
                  userIdHex: widget.userIdHex,
                  index: index,
                  isPrecached: _precachedThumbnailUrls.contains(
                    eventEntry.videoEvent.thumbnailUrl,
                  ),
                  onTap: () {
                    // Adjust index to account for uploading videos at the top
                    final publishedIndex = index - uploadingCount;
                    if (publishedIndex >= 0) {
                      _onVideoTapped(
                        publishedIndex,
                        onLoadMore: loadMoreProfileVideos,
                      );
                    }
                  },
                ),
              };
            }, childCount: allVideos.length),
          ),
        ),
        if (isLoadingMore) const ProfileTabLoadingMoreSliver(),
      ],
    );
  }
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
              errorBuilder: (_, _, _) => const ProfileTabThumbnailPlaceholder(),
            )
          else
            const ProfileTabThumbnailPlaceholder(),
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
    this.isPrecached = false,
  });

  final VideoEvent videoEvent;
  final String userIdHex;
  final int index;
  final VoidCallback onTap;
  final bool isPrecached;

  @override
  Widget build(BuildContext context) => Semantics(
    identifier: 'video_thumbnail_$index',
    label: context.l10n.profileVideoThumbnailLabel(index + 1),
    button: true,
    child: GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: VineTheme.cardBackground),
          child: ProfileTabThumbnail(
            thumbnailUrl: videoEvent.thumbnailUrl,
            isPrecached: isPrecached,
          ),
        ),
      ),
    ),
  );
}
