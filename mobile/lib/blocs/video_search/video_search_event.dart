// ABOUTME: Events for the VideoSearchBloc
// ABOUTME: Defines actions for searching videos and clearing results

part of 'video_search_bloc.dart';

/// Base class for all video search events
sealed class VideoSearchEvent extends Equatable {
  const VideoSearchEvent();

  @override
  List<Object?> get props => [];
}

/// Request to search for videos with a query (debounced)
final class VideoSearchQueryChanged extends VideoSearchEvent {
  const VideoSearchQueryChanged(this.query, {this.fetchResults = true});

  /// The search query string
  final String query;

  /// Whether to fetch full progressive results instead of only a local count.
  final bool fetchResults;

  @override
  List<Object?> get props => [query, fetchResults];
}

/// Request to clear search results and reset to initial state
final class VideoSearchCleared extends VideoSearchEvent {
  const VideoSearchCleared();
}

/// Request to load the next page of video search results from the API
final class VideoSearchLoadMore extends VideoSearchEvent {
  const VideoSearchLoadMore();
}
