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
    this.networkResults = const [],
    this.vanishedPubkeys = const {},
    this.peerLabels,
  });

  /// Current status of the search flow.
  final NewMessageSearchStatus status;

  /// All followed contacts, sorted alphabetically.
  final List<UserProfile> contacts;

  /// Current search query (trimmed).
  final String query;

  /// Search results: filtered contacts merged with network results.
  final List<UserProfile> results;

  /// Unfiltered candidates returned by the current network query.
  ///
  /// Retained separately so a late tombstone or locale change can re-run the
  /// rendered-name match instead of leaving [results] keyed on stale labels.
  final List<UserProfile> networkResults;

  /// Pubkeys carrying a NIP-62 vanish tombstone, mirrored live from
  /// `ProfileRepository.watchVanishedPubkeys()`.
  ///
  /// Held in state rather than sampled at match time so the sort and the
  /// filter see the same set the row renders with, the way
  /// `ConversationListBloc` holds it for the inbox index.
  final Set<String> vanishedPubkeys;

  /// The substitute strings [dmPeerName] needs, pushed down from the sheet.
  ///
  /// Null until the first `didChangeDependencies` delivers them — matching on
  /// a substitute needs the translated string, and there is nothing better to
  /// match on before it arrives.
  final DmPeerLabels? peerLabels;

  /// Whether a search query is active.
  bool get isSearchActive => query.isNotEmpty;

  NewMessageSearchState copyWith({
    NewMessageSearchStatus? status,
    List<UserProfile>? contacts,
    String? query,
    List<UserProfile>? results,
    List<UserProfile>? networkResults,
    Set<String>? vanishedPubkeys,
    DmPeerLabels? peerLabels,
  }) {
    return NewMessageSearchState(
      status: status ?? this.status,
      contacts: contacts ?? this.contacts,
      query: query ?? this.query,
      results: results ?? this.results,
      networkResults: networkResults ?? this.networkResults,
      vanishedPubkeys: vanishedPubkeys ?? this.vanishedPubkeys,
      peerLabels: peerLabels ?? this.peerLabels,
    );
  }

  @override
  List<Object?> get props => [
    status,
    contacts,
    query,
    results,
    networkResults,
    vanishedPubkeys,
    peerLabels,
  ];
}
