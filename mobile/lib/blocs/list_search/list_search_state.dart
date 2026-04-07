// ABOUTME: State class for the ListSearchBloc.
// ABOUTME: Holds status, query, and curated video list search results.

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
    this.results = const [],
  });

  /// The current status of the search.
  final ListSearchStatus status;

  /// The current search query.
  final String query;

  /// Curated video lists matching the search.
  // TODO(#2853): Add people list results field.
  final List<CuratedList> results;

  /// Create a copy with updated values.
  ListSearchState copyWith({
    ListSearchStatus? status,
    String? query,
    List<CuratedList>? results,
  }) {
    return ListSearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      results: results ?? this.results,
    );
  }

  @override
  List<Object> get props => [status, query, results];
}
