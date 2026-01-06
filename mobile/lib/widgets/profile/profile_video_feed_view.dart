// ABOUTME: Fullscreen video feed view for profile screens
// ABOUTME: Reusable between own profile and others' profile screens

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/mixins/page_controller_sync_mixin.dart';
import 'package:openvine/mixins/video_prefetch_mixin.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';

/// Fullscreen video feed view for profile screens.
///
/// Displays videos in a vertical PageView with URL sync, prefetching,
/// and pagination support.
class ProfileVideoFeedView extends ConsumerStatefulWidget {
  const ProfileVideoFeedView({
    required this.npub,
    required this.userIdHex,
    required this.isOwnProfile,
    required this.videos,
    required this.videoIndex,
    required this.onPageChanged,
    super.key,
  });

  /// The npub of the profile (for URL updates).
  final String npub;

  /// The hex public key of the profile.
  final String userIdHex;

  /// Whether this is the current user's own profile.
  final bool isOwnProfile;

  /// List of videos to display.
  final List<VideoEvent> videos;

  /// Current video index from URL.
  final int videoIndex;

  /// Callback when page changes (for URL updates).
  final void Function(int newIndex) onPageChanged;

  @override
  ConsumerState<ProfileVideoFeedView> createState() =>
      _ProfileVideoFeedViewState();
}

class _ProfileVideoFeedViewState extends ConsumerState<ProfileVideoFeedView>
    with VideoPrefetchMixin, PageControllerSyncMixin {
  PageController? _pageController;
  int? _lastVideoUrlIndex;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void didUpdateWidget(ProfileVideoFeedView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle video index changes from URL
    if (widget.videoIndex != oldWidget.videoIndex) {
      _syncControllerToUrl();
    }
  }

  void _initializeController() {
    final safeIndex = widget.videoIndex.clamp(0, widget.videos.length - 1);

    Log.debug(
      '🎬 ProfileVideoFeedView init: videoIndex=${widget.videoIndex}, '
      'safeIndex=$safeIndex, videos.length=${widget.videos.length}',
      name: 'ProfileVideoFeedView',
      category: LogCategory.video,
    );

    _pageController = PageController(initialPage: safeIndex);
    _lastVideoUrlIndex = widget.videoIndex;

    // Pre-initialize controllers for adjacent videos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      preInitializeControllers(
        ref: ref,
        currentIndex: safeIndex,
        videos: widget.videos,
      );
    });
  }

  void _syncControllerToUrl() {
    if (_pageController == null) return;

    final listIndex = widget.videoIndex;
    final targetIndex = listIndex.clamp(0, widget.videos.length - 1);
    final currentPage = _pageController!.hasClients
        ? _pageController!.page?.round()
        : null;

    Log.debug(
      '🔄 Checking sync: urlIndex=$listIndex, lastUrlIndex=$_lastVideoUrlIndex, '
      'hasClients=${_pageController!.hasClients}, currentPage=$currentPage, '
      'targetIndex=$targetIndex',
      name: 'ProfileVideoFeedView',
      category: LogCategory.video,
    );

    if (shouldSync(
      urlIndex: listIndex,
      lastUrlIndex: _lastVideoUrlIndex,
      controller: _pageController,
      targetIndex: targetIndex,
    )) {
      Log.info(
        '📍 Syncing PageController: $currentPage → $targetIndex',
        name: 'ProfileVideoFeedView',
        category: LogCategory.video,
      );
      _lastVideoUrlIndex = listIndex;
      syncPageController(
        controller: _pageController!,
        targetIndex: listIndex,
        itemCount: widget.videos.length,
      );
    }
  }

  void _handlePageChanged(int newIndex) {
    // Update URL when swiping
    if (newIndex != widget.videoIndex) {
      widget.onPageChanged(newIndex);
    }

    // Trigger pagination near end
    if (newIndex >= widget.videos.length - 2) {
      ref.read(profileFeedProvider(widget.userIdHex).notifier).loadMore();
    }

    // Prefetch videos around current index
    checkForPrefetch(currentIndex: newIndex, videos: widget.videos);

    // Pre-initialize controllers for adjacent videos
    preInitializeControllers(
      ref: ref,
      currentIndex: newIndex,
      videos: widget.videos,
    );

    // Dispose controllers outside the keep range to free memory
    disposeControllersOutsideRange(
      ref: ref,
      currentIndex: newIndex,
      videos: widget.videos,
    );
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      key: const Key('profile-video-page-view'),
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: widget.videos.length,
      onPageChanged: _handlePageChanged,
      itemBuilder: (context, index) {
        if (index >= widget.videos.length) return const SizedBox.shrink();

        // Use PageController as source of truth for active video
        final currentPage = _pageController?.page?.round() ?? widget.videoIndex;
        final isActive = index == currentPage;

        final video = widget.videos[index];
        return VideoFeedItem(
          key: ValueKey('video-${video.stableId}'),
          video: video,
          index: index,
          hasBottomNavigation: false,
          forceShowOverlay: widget.isOwnProfile,
          isActiveOverride: isActive,
          contextTitle: ref
              .read(fetchUserProfileProvider(widget.userIdHex))
              .value
              ?.betterDisplayName('Profile'),
        );
      },
    );
  }
}
