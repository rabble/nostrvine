// ABOUTME: Events for the UserSearchBloc
// ABOUTME: Defines actions for searching users and clearing results

part of 'user_search_bloc.dart';

/// Base class for all user search events
sealed class UserSearchEvent extends Equatable {
  const UserSearchEvent();

  @override
  List<Object?> get props => [];
}

/// Request to search for users with a query
final class UserSearchQueryChanged extends UserSearchEvent {
  const UserSearchQueryChanged(this.query);

  /// The search query string
  final String query;

  @override
  List<Object?> get props => [query];
}

/// Request to clear search results and reset to initial state
final class UserSearchCleared extends UserSearchEvent {
  const UserSearchCleared();
}
