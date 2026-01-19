// ABOUTME: Bridge provider for liked videos BLoC state
// ABOUTME: Allows Riverpod providers to access BLoC-managed liked videos state

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:models/models.dart';
import 'package:openvine/state/video_feed_state.dart';

/// State provider that holds the current liked videos feed state.
///
/// This provider acts as a bridge between the BLoC-managed [ProfileLikedVideosBloc]
/// and Riverpod providers like [activeVideoIdProvider] that need to access the
/// liked videos list.
///
/// The [LikedVideosScreenRouter] is responsible for syncing the BLoC state
/// to this provider when videos are loaded.
final likedVideosFeedStateProvider = StateProvider<LikedVideosBridgeState>(
  (ref) => const LikedVideosBridgeState.initial(),
);

/// State class for the liked videos bridge.
///
/// Used to sync BLoC state to Riverpod for [activeVideoIdProvider].
class LikedVideosBridgeState {
  const LikedVideosBridgeState({required this.isLoading, required this.videos});

  const LikedVideosBridgeState.initial() : isLoading = true, videos = const [];

  final bool isLoading;
  final List<VideoEvent> videos;
}

/// Provider that exposes liked videos as [AsyncValue<VideoFeedState>] for
/// compatibility with [activeVideoIdProvider].
///
/// Returns:
/// - [AsyncLoading] when the bridge state is loading
/// - [AsyncData] with [VideoFeedState] when videos are available
final likedVideosFeedProvider = Provider<AsyncValue<VideoFeedState>>((ref) {
  final bridgeState = ref.watch(likedVideosFeedStateProvider);

  if (bridgeState.isLoading) {
    return const AsyncLoading();
  }

  return AsyncData(
    VideoFeedState(
      videos: bridgeState.videos,
      hasMoreContent: false,
      isLoadingMore: false,
    ),
  );
});
