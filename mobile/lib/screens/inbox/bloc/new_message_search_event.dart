// ABOUTME: Events for the NewMessageSearchBloc.
// ABOUTME: Covers contact loading, query changes, and clearing search.

part of 'new_message_search_bloc.dart';

/// Base class for new message search events.
sealed class NewMessageSearchEvent extends Equatable {
  const NewMessageSearchEvent();

  @override
  List<Object?> get props => [];
}

/// Load followed contacts from the repository.
final class NewMessageSearchStarted extends NewMessageSearchEvent {
  const NewMessageSearchStarted();
}

/// User typed or changed the search query.
final class NewMessageSearchQueryChanged extends NewMessageSearchEvent {
  const NewMessageSearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// User cleared the search field.
final class NewMessageSearchCleared extends NewMessageSearchEvent {
  const NewMessageSearchCleared();
}
