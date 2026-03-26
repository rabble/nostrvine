// ABOUTME: State class for the UserSearchBloc
// ABOUTME: Represents all possible states of user search results

part of 'user_search_bloc.dart';

/// Enum representing the status of the user search
enum UserSearchStatus {
  /// Initial state, no search performed yet
  initial,

  /// Currently searching for users (progressive results may be arriving)
  loading,

  /// Search completed successfully
  success,

  /// An error occurred while searching
  failure,
}

/// State class for the UserSearchBloc
final class UserSearchState extends Equatable {
  const UserSearchState({
    this.status = UserSearchStatus.initial,
    this.query = '',
    this.results = const [],
    this.resultCount,
    this.offset = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  /// The current status of the search
  final UserSearchStatus status;

  /// The current search query
  final String query;

  /// The list of user profiles matching the search
  final List<UserProfile> results;

  /// Lightweight count for tab badges when full results were not fetched.
  final int? resultCount;

  /// Current pagination offset
  final int offset;

  /// Whether more results are available
  final bool hasMore;

  /// Whether a "load more" request is in progress
  final bool isLoadingMore;

  /// Create a copy with updated values
  UserSearchState copyWith({
    UserSearchStatus? status,
    String? query,
    List<UserProfile>? results,
    Object? resultCount = _unset,
    int? offset,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return UserSearchState(
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
