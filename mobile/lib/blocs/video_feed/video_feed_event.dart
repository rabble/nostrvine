// ABOUTME: Events for VideoFeedBloc - unified feed with mode switching
// ABOUTME: Supports For You, Home (following), New (latest), and Popular feed modes

part of 'video_feed_bloc.dart';

/// Base class for all video feed events.
sealed class VideoFeedEvent extends Equatable {
  const VideoFeedEvent();
}

/// Start the video feed with a specific mode.
///
/// Dispatched when the feed screen initializes. Triggers initial
/// data loading for the specified [mode]. If a mode was previously persisted
/// to SharedPreferences, the bloc will restore that mode instead.
final class VideoFeedStarted extends VideoFeedEvent {
  const VideoFeedStarted({this.mode = FeedMode.forYou});

  /// The feed mode to start with.
  final FeedMode mode;

  @override
  List<Object?> get props => [mode];
}

/// Switch to a different feed mode.
///
/// Triggers loading of videos for the new mode. Previous videos
/// are cleared and fresh data is fetched.
final class VideoFeedModeChanged extends VideoFeedEvent {
  const VideoFeedModeChanged(this.mode);

  /// The new feed mode to switch to.
  final FeedMode mode;

  @override
  List<Object?> get props => [mode];
}

/// Request to load more videos (pagination).
///
/// Only effective when in [VideoFeedStatus.success] state and
/// [hasMore] is true. Uses cursor-based pagination via the
/// oldest video's createdAt timestamp.
final class VideoFeedLoadMoreRequested extends VideoFeedEvent {
  const VideoFeedLoadMoreRequested();

  @override
  List<Object?> get props => [];
}

/// Request to refresh the current feed.
///
/// Clears existing videos and fetches fresh data from the beginning.
/// Used for pull-to-refresh functionality.
final class VideoFeedRefreshRequested extends VideoFeedEvent {
  const VideoFeedRefreshRequested();

  @override
  List<Object?> get props => [];
}

/// Request an auto-refresh of the home feed.
///
/// Dispatched by the UI on app resume (background → foreground).
/// The bloc will only perform the refresh if:
/// - The current feed mode is [FeedMode.home]
/// - Enough time has passed since the last successful load
final class VideoFeedAutoRefreshRequested extends VideoFeedEvent {
  const VideoFeedAutoRefreshRequested();

  @override
  List<Object?> get props => [];
}

/// The following list changed.
///
/// Dispatched internally when the [FollowRepository.followingStream]
/// emits a new list. Triggers a refresh of the home feed so the user
/// sees videos from their updated following list.
final class VideoFeedFollowingListChanged extends VideoFeedEvent {
  const VideoFeedFollowingListChanged(this.followingPubkeys);

  /// The updated list of followed pubkeys.
  final List<String> followingPubkeys;

  @override
  List<Object?> get props => [followingPubkeys];
}
