// ABOUTME: State class for the VideoSearchBloc
// ABOUTME: Represents search state with status, query, and results

part of 'video_search_bloc.dart';

/// Enum representing the status of the video search
enum VideoSearchStatus {
  /// Initial state, no search performed yet
  initial,

  /// Currently searching for videos
  searching,

  /// Search completed successfully
  success,

  /// An error occurred while searching
  failure,
}

/// State class for the VideoSearchBloc
final class VideoSearchState extends Equatable {
  const VideoSearchState({
    this.status = VideoSearchStatus.initial,
    this.query = '',
    this.videos = const [],
    this.resultCount,
  });

  /// The current status of the search
  final VideoSearchStatus status;

  /// The current search query
  final String query;

  /// The list of videos matching the search
  final List<VideoEvent> videos;

  /// Lightweight count for tab badges when full results were not fetched.
  final int? resultCount;

  /// Create a copy with updated values
  VideoSearchState copyWith({
    VideoSearchStatus? status,
    String? query,
    List<VideoEvent>? videos,
    Object? resultCount = _unset,
  }) {
    return VideoSearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      videos: videos ?? this.videos,
      resultCount: identical(resultCount, _unset)
          ? this.resultCount
          : resultCount as int?,
    );
  }

  @override
  List<Object> get props => [status, query, videos, resultCount ?? -1];

  static const Object _unset = Object();
}
