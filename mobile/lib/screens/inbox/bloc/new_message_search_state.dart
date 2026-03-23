// ABOUTME: State for the NewMessageSearchBloc.
// ABOUTME: Tracks contact loading, search status, and display results.

part of 'new_message_search_bloc.dart';

/// Status of the new message search screen.
enum NewMessageSearchStatus {
  /// Contacts are being loaded from the follow list.
  loadingContacts,

  /// Contacts loaded, no active search query.
  idle,

  /// A network search is in progress.
  searching,

  /// Network search completed successfully.
  searchSuccess,

  /// Network search failed.
  searchFailure,
}

/// State for the new message recipient search.
final class NewMessageSearchState extends Equatable {
  const NewMessageSearchState({
    this.status = NewMessageSearchStatus.loadingContacts,
    this.contacts = const [],
    this.query = '',
    this.results = const [],
  });

  /// Current status of the search flow.
  final NewMessageSearchStatus status;

  /// All followed contacts, sorted alphabetically.
  final List<UserProfile> contacts;

  /// Current search query (trimmed).
  final String query;

  /// Search results: filtered contacts merged with network results.
  final List<UserProfile> results;

  /// Whether a search query is active.
  bool get isSearchActive => query.isNotEmpty;

  NewMessageSearchState copyWith({
    NewMessageSearchStatus? status,
    List<UserProfile>? contacts,
    String? query,
    List<UserProfile>? results,
  }) {
    return NewMessageSearchState(
      status: status ?? this.status,
      contacts: contacts ?? this.contacts,
      query: query ?? this.query,
      results: results ?? this.results,
    );
  }

  @override
  List<Object> get props => [status, contacts, query, results];
}
