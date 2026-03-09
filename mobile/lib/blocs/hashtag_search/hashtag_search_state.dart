// ABOUTME: State class for the HashtagSearchBloc
// ABOUTME: Represents all possible states of hashtag search results

part of 'hashtag_search_bloc.dart';

/// Enum representing the status of the hashtag search
enum HashtagSearchStatus {
  /// Initial state, no search performed yet
  initial,

  /// Currently searching for hashtags
  loading,

  /// Search completed successfully
  success,

  /// An error occurred while searching
  failure,
}

/// State class for the HashtagSearchBloc
final class HashtagSearchState extends Equatable {
  const HashtagSearchState({
    this.status = HashtagSearchStatus.initial,
    this.query = '',
    this.results = const [],
    this.resultCount,
  });

  /// The current status of the search
  final HashtagSearchStatus status;

  /// The current search query
  final String query;

  /// The list of hashtags matching the search
  final List<String> results;

  /// Lightweight count for tab badges when full results were not fetched.
  final int? resultCount;

  /// Create a copy with updated values
  HashtagSearchState copyWith({
    HashtagSearchStatus? status,
    String? query,
    List<String>? results,
    Object? resultCount = _unset,
  }) {
    return HashtagSearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      results: results ?? this.results,
      resultCount: identical(resultCount, _unset)
          ? this.resultCount
          : resultCount as int?,
    );
  }

  @override
  List<Object> get props => [status, query, results, resultCount ?? -1];

  static const Object _unset = Object();
}
