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
    this.offset = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  /// The current status of the search
  final HashtagSearchStatus status;

  /// The current search query
  final String query;

  /// The list of hashtags matching the search
  final List<String> results;

  /// Lightweight count for tab badges when full results were not fetched.
  final int? resultCount;

  /// Pagination offset for the next load-more request.
  final int offset;

  /// Whether more results are available from the server.
  final bool hasMore;

  /// Whether a load-more request is in flight.
  final bool isLoadingMore;

  /// Create a copy with updated values
  HashtagSearchState copyWith({
    HashtagSearchStatus? status,
    String? query,
    List<String>? results,
    Object? resultCount = _unset,
    int? offset,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return HashtagSearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      results: results ?? this.results,
      resultCount: identical(resultCount, _unset)
          ? this.resultCount
          : resultCount as int?,
      offset: offset ?? this.offset,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object> get props => [
    status,
    query,
    results,
    resultCount ?? -1,
    offset,
    hasMore,
    isLoadingMore,
  ];

  static const Object _unset = Object();
}
