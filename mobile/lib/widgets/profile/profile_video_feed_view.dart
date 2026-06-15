// ABOUTME: Fullscreen video feed view for profile screens
// ABOUTME: Resolves the profile feed through a FeedRepository (#3383)

import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_cubit.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_scope.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/utils/video_identity.dart';
import 'package:rxdart/rxdart.dart';

/// Fullscreen video feed view for profile screens.
///
/// Wraps [PooledFullscreenVideoFeedScreen] with a [ProfileFeedScope] so the
/// fullscreen feed benefits from the pooled player, auto-advance and
/// prefetching machinery shared with the main feed. The feed is resolved
/// through a [StreamFeedRepository] bound to the scope's [ProfileFeedCubit],
/// so profile-specific metadata updates (like loop counts) survive the
/// launching grid unmounting. Keeps the URL in sync via [onPageChanged].
class ProfileVideoFeedView extends ConsumerWidget {
  const ProfileVideoFeedView({
    required this.npub,
    required this.userIdHex,
    required this.videoIndex,
    required this.onPageChanged,
    this.videos = const [],
    this.initialVideoId,
    this.initialStableId,
    this.contextTitleOverride,
    super.key,
  });

  /// The npub of the profile (carried for URL updates at the callsite).
  final String npub;

  /// The hex public key of the profile.
  final String userIdHex;

  /// Initial list of videos to seed the feed with before the cubit resolves.
  final List<VideoEvent> videos;

  /// Current video index from the URL.
  final int videoIndex;

  /// Optional specific tapped video identity for resolving the initial index
  /// against the live cubit-backed feed.
  final String? initialVideoId;
  final String? initialStableId;

  /// Optional title override when the caller already has context.
  final String? contextTitleOverride;

  /// Callback when the page changes (for URL updates).
  final void Function(int newIndex) onPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contextTitle =
        contextTitleOverride ??
        ref
            .watch(fetchUserProfileProvider(userIdHex))
            .value
            ?.betterDisplayName(context.l10n.profileTitle);

    return ProfileFeedScope(
      userIdHex: userIdHex,
      child: _ProfileFullscreenContent(
        userIdHex: userIdHex,
        seedVideos: videos,
        videoIndex: videoIndex,
        initialVideoId: initialVideoId,
        initialStableId: initialStableId,
        contextTitle: contextTitle,
        onPageChanged: onPageChanged,
      ),
    );
  }
}

/// Inner content that binds a [StreamFeedRepository] to the scoped
/// [ProfileFeedCubit] exactly once, then hands it to the fullscreen screen.
class _ProfileFullscreenContent extends StatefulWidget {
  const _ProfileFullscreenContent({
    required this.userIdHex,
    required this.seedVideos,
    required this.videoIndex,
    required this.onPageChanged,
    this.initialVideoId,
    this.initialStableId,
    this.contextTitle,
  });

  final String userIdHex;
  final List<VideoEvent> seedVideos;
  final int videoIndex;
  final String? initialVideoId;
  final String? initialStableId;
  final String? contextTitle;
  final void Function(int newIndex) onPageChanged;

  @override
  State<_ProfileFullscreenContent> createState() =>
      _ProfileFullscreenContentState();
}

class _ProfileFullscreenContentState extends State<_ProfileFullscreenContent> {
  late final ProfileFeedCubit _cubit;
  late final FeedRepository _feedRepository;
  late final int _initialIndex;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<ProfileFeedCubit>();

    // Prefer the live cubit list, falling back to the tapped seed list until
    // the cubit resolves. `startWith` guarantees the first list reaches the
    // FullscreenFeedBloc before it subscribes.
    List<VideoEvent> effective(ProfileFeedState state) =>
        state.videos.isNotEmpty ? state.videos : widget.seedVideos;

    final initialState = _cubit.state;
    _initialIndex = _resolveInitialIndex(effective(initialState));

    _feedRepository = StreamFeedRepository(
      videos: _cubit.stream.map(effective).startWith(effective(initialState)),
      hasMore: _cubit.stream
          .map((state) => state.hasMoreContent)
          .startWith(initialState.hasMoreContent),
      onLoadMore: () async => _cubit.add(const ProfileFeedLoadMoreRequested()),
    );
  }

  int _resolveInitialIndex(List<VideoEvent> videos) {
    if (videos.isEmpty) return 0;

    final initialVideoId = widget.initialVideoId;
    final initialStableId = widget.initialStableId;
    if (initialVideoId != null || initialStableId != null) {
      final resolved = indexOfVideoIdentity(
        videos,
        videoId: initialVideoId,
        stableId: initialStableId,
      );
      if (resolved >= 0) return resolved;
    }

    return widget.videoIndex.clamp(0, videos.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    return PooledFullscreenVideoFeedScreen(
      source: ProfileViewSource(widget.userIdHex),
      feedRepository: _feedRepository,
      initialIndex: _initialIndex,
      initialVideoId: widget.initialVideoId,
      initialStableId: widget.initialStableId,
      trafficSource: ViewTrafficSource.profile,
      contextTitle: widget.contextTitle,
      onPageChanged: widget.onPageChanged,
    );
  }
}
