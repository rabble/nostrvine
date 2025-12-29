// ABOUTME: Simple state model for video lists without global feed modes
// ABOUTME: Represents the current state of a video list with basic metadata

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:openvine/models/video_event.dart';

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
  }) = _VideoFeedState;

  const VideoFeedState._();
}
