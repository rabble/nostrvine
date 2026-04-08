// ABOUTME: Events for the ListSearchBloc.
// ABOUTME: Defines actions for searching lists and clearing results.

part of 'list_search_bloc.dart';

/// Base class for all list search events.
sealed class ListSearchEvent extends Equatable {
  const ListSearchEvent();

  @override
  List<Object?> get props => [];
}

/// Request to search for lists with a query.
final class ListSearchQueryChanged extends ListSearchEvent {
  const ListSearchQueryChanged(this.query);

  /// The search query string.
  final String query;

  @override
  List<Object?> get props => [query];
}

/// Request to clear search results and reset to initial state.
final class ListSearchCleared extends ListSearchEvent {
  const ListSearchCleared();
}
