// ABOUTME: Events for VideoFeedBloc - unified feed with mode switching
// ABOUTME: Supports Home (following), New (latest), and Popular feed modes

part of 'video_feed_bloc.dart';

/// Base class for all video feed events.
sealed class VideoFeedEvent {
  const VideoFeedEvent();
}

/// Start the video feed with a specific mode.
///
/// Dispatched when the feed screen initializes. Triggers initial
/// data loading for the specified [mode].
final class VideoFeedStarted extends VideoFeedEvent {
  const VideoFeedStarted({this.mode = FeedMode.home});

  /// The feed mode to start with.
  final FeedMode mode;
}

/// Switch to a different feed mode.
///
/// Triggers loading of videos for the new mode. Previous videos
/// are cleared and fresh data is fetched.
final class VideoFeedModeChanged extends VideoFeedEvent {
  const VideoFeedModeChanged(this.mode);

  /// The new feed mode to switch to.
  final FeedMode mode;
}

/// Request to load more videos (pagination).
///
/// Only effective when in [VideoFeedStatus.success] state and
/// [hasMore] is true. Uses cursor-based pagination via the
/// oldest video's createdAt timestamp.
final class VideoFeedLoadMoreRequested extends VideoFeedEvent {
  const VideoFeedLoadMoreRequested();
}

/// Request to refresh the current feed.
///
/// Clears existing videos and fetches fresh data from the beginning.
/// Used for pull-to-refresh functionality.
final class VideoFeedRefreshRequested extends VideoFeedEvent {
  const VideoFeedRefreshRequested();
}
