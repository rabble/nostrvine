// ABOUTME: Events for the HashtagSearchBloc
// ABOUTME: Defines actions for searching hashtags and clearing results

part of 'hashtag_search_bloc.dart';

/// Base class for all hashtag search events
sealed class HashtagSearchEvent extends Equatable {
  const HashtagSearchEvent();

  @override
  List<Object?> get props => [];
}

/// Request to search for hashtags with a query
final class HashtagSearchQueryChanged extends HashtagSearchEvent {
  const HashtagSearchQueryChanged(this.query, {this.fetchResults = true});

  /// The search query string
  final String query;

  /// Whether to fetch full results instead of only a local count.
  final bool fetchResults;

  @override
  List<Object?> get props => [query, fetchResults];
}

/// Request to load the next page of hashtag results.
final class HashtagSearchLoadMore extends HashtagSearchEvent {
  const HashtagSearchLoadMore();
}

/// Request to clear search results and reset to initial state
final class HashtagSearchCleared extends HashtagSearchEvent {
  const HashtagSearchCleared();
}
