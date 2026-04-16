// ABOUTME: Simple state model for video lists without global feed modes
// ABOUTME: Represents the current state of a video list with basic metadata

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:models/models.dart';

part 'video_feed_state.freezed.dart';

/// State model for video lists
@freezed
sealed class VideoFeedState with _$VideoFeedState {
  const factory VideoFeedState({
    /// List of videos in the feed
    required List<VideoEvent> videos,

    /// Whether more content can be loaded
    required bool hasMoreContent,

    /// Loading state for pagination
    @Default(false) bool isLoadingMore,

    /// Refreshing state for pull-to-refresh
    @Default(false) bool isRefreshing,

    /// Whether this is the initial load (videos may still be arriving)
    /// When true and videos is empty, show loading indicator instead of empty state
    @Default(false) bool isInitialLoad,

    /// Error message if any
    String? error,

    /// Timestamp of last update
    DateTime? lastUpdated,

    /// Maps video IDs to the set of curated list IDs they appear in
    /// Used to show "From list: X" attribution chip on videos
    @Default({}) Map<String, Set<String>> videoListSources,

    /// Set of video IDs that appear ONLY from subscribed lists (not from follows)
    /// These videos should show the list attribution chip in the UI
    @Default({}) Set<String> listOnlyVideoIds,

    /// Total video count from the server's X-Total-Count header.
    /// When available, this is more accurate than `videos.length` which
    /// only reflects the number of loaded videos.
    int? totalVideoCount,

    /// Whether a REST call that will resolve [totalVideoCount] is currently
    /// in flight. Stays `true` from the moment the fetch starts until it
    /// settles (success, empty, or failure). UI uses this to distinguish
    /// "still loading, authoritative count may still arrive" from
    /// "settled, no authoritative count available — fall back to
    /// videos.length".
    @Default(false) bool isFetchingTotalCount,
  }) = _VideoFeedState;

  const VideoFeedState._();
}
