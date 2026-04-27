// ABOUTME: Fullscreen video feed view for profile screens
// ABOUTME: Wraps PooledFullscreenVideoFeedScreen with profile-feed streams

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:rxdart/rxdart.dart';

/// Fullscreen video feed view for profile screens.
///
/// Streams [profileFeedProvider] updates into [PooledFullscreenVideoFeedScreen]
/// so the profile fullscreen feed benefits from the pooled player, auto-advance
/// and prefetching machinery shared with the main feed. Keeps the URL in sync
/// via [onPageChanged].
class ProfileVideoFeedView extends ConsumerStatefulWidget {
  const ProfileVideoFeedView({
    required this.npub,
    required this.userIdHex,
    required this.videos,
    required this.videoIndex,
    required this.onPageChanged,
    super.key,
  });

  /// The npub of the profile (carried for URL updates at the callsite).
  final String npub;

  /// The hex public key of the profile.
  final String userIdHex;

  /// Initial list of videos to seed the feed with.
  final List<VideoEvent> videos;

  /// Current video index from the URL.
  final int videoIndex;

  /// Callback when the page changes (for URL updates).
  final void Function(int newIndex) onPageChanged;

  @override
  ConsumerState<ProfileVideoFeedView> createState() =>
      _ProfileVideoFeedViewState();
}

class _ProfileVideoFeedViewState extends ConsumerState<ProfileVideoFeedView> {
  late final StreamController<List<VideoEvent>> _videosController;
  late final StreamController<bool> _hasMoreController;
  List<VideoEvent>? _lastVideos;
  bool? _lastHasMore;

  @override
  void initState() {
    super.initState();
    _videosController = StreamController<List<VideoEvent>>.broadcast();
    _hasMoreController = StreamController<bool>.broadcast();
    // Seed with initial videos so the BLoC receives them on first subscription.
    _pushVideos(widget.videos);
  }

  @override
  void didUpdateWidget(ProfileVideoFeedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.videos, oldWidget.videos)) {
      _pushVideos(widget.videos);
    }
  }

  @override
  void dispose() {
    _videosController.close();
    _hasMoreController.close();
    super.dispose();
  }

  void _pushVideos(List<VideoEvent> videos) {
    if (videos.isEmpty) return;
    if (identical(videos, _lastVideos)) return;
    _lastVideos = videos;
    if (!_videosController.isClosed) _videosController.add(videos);
  }

  void _pushHasMore(bool hasMore) {
    if (_lastHasMore == hasMore) return;
    _lastHasMore = hasMore;
    if (!_hasMoreController.isClosed) _hasMoreController.add(hasMore);
  }

  @override
  Widget build(BuildContext context) {
    // Watch feed state only for the hasMoreContent flag; pushing videos into
    // the stream is handled in initState / didUpdateWidget so each rebuild
    // doesn't trigger a redundant stream event.
    final feedState = ref
        .watch(profileFeedProvider(widget.userIdHex))
        .asData
        ?.value;
    final hasMoreContent = feedState?.hasMoreContent ?? false;
    _pushHasMore(hasMoreContent);

    final safeIndex = widget.videos.isEmpty
        ? 0
        : widget.videoIndex.clamp(0, widget.videos.length - 1);

    final contextTitle = ref
        .watch(fetchUserProfileProvider(widget.userIdHex))
        .value
        ?.betterDisplayName(context.l10n.profileTitle);

    return PooledFullscreenVideoFeedScreen(
      // Pass the raw broadcast stream — seeding happened in initState.
      videosStream: _videosController.stream,
      initialIndex: safeIndex,
      trafficSource: ViewTrafficSource.profile,
      contextTitle: contextTitle,
      onLoadMore: hasMoreContent
          ? () => ref
                .read(profileFeedProvider(widget.userIdHex).notifier)
                .loadMore()
          : null,
      hasMoreStream: _hasMoreController.stream.startWith(hasMoreContent),
      removedIdsStream: ref.read(videoEventServiceProvider).removedVideoIds,
      onPageChanged: widget.onPageChanged,
    );
  }
}
