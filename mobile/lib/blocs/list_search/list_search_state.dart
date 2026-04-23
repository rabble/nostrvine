// ABOUTME: State class for the ListSearchBloc.
// ABOUTME: Holds status, query, curated video list results, and people list results.

part of 'list_search_bloc.dart';

/// Status of the list search.
enum ListSearchStatus {
  /// Initial state, no search performed yet.
  initial,

  /// Currently searching for lists.
  loading,

  /// Search completed successfully.
  success,

  /// An error occurred while searching.
  failure,
}

/// State class for the ListSearchBloc.
final class ListSearchState extends Equatable {
  const ListSearchState({
    this.status = ListSearchStatus.initial,
    this.query = '',
    this.videoResults = const [],
    this.peopleResults = const [],
  });

  /// The current status of the search.
  final ListSearchStatus status;

  /// The current search query.
  final String query;

  /// Curated video lists (kind 30005) matching the search.
  final List<CuratedList> videoResults;

  /// People lists (kind 30000) matching the search.
  final List<UserList> peopleResults;

  /// Create a copy with updated values.
  ListSearchState copyWith({
    ListSearchStatus? status,
    String? query,
    List<CuratedList>? videoResults,
    List<UserList>? peopleResults,
  }) {
    return ListSearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      videoResults: videoResults ?? this.videoResults,
      peopleResults: peopleResults ?? this.peopleResults,
    );
  }

  @override
  List<Object> get props => [status, query, videoResults, peopleResults];
}
