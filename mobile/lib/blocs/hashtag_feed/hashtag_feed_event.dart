// ABOUTME: Events for HashtagFeedBloc - hashtag video feed
// ABOUTME: Supports loading, pagination, and refresh for hashtag feeds

part of 'hashtag_feed_bloc.dart';

/// Base class for all hashtag feed events.
sealed class HashtagFeedEvent extends Equatable {
  const HashtagFeedEvent();
}

/// Start loading videos for a hashtag.
///
/// Dispatched when the hashtag feed screen initializes. Triggers
/// initial data loading for the specified [hashtag].
final class HashtagFeedStarted extends HashtagFeedEvent {
  const HashtagFeedStarted(this.hashtag);

  /// The hashtag to load videos for (without #).
  final String hashtag;

  @override
  List<Object?> get props => [hashtag];
}

/// Request to load more videos (pagination).
///
/// Only effective when in [HashtagFeedStatus.success] state and
/// [hasMore] is true. Uses offset-based pagination for Funnelcake
/// or cursor-based pagination for relay fallback.
final class HashtagFeedLoadMoreRequested extends HashtagFeedEvent {
  const HashtagFeedLoadMoreRequested();

  @override
  List<Object?> get props => [];
}

/// Request to refresh the current hashtag feed.
///
/// Clears existing videos and fetches fresh data from the beginning.
final class HashtagFeedRefreshRequested extends HashtagFeedEvent {
  const HashtagFeedRefreshRequested();

  @override
  List<Object?> get props => [];
}
