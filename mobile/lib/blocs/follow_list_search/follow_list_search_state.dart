// ABOUTME: State for FollowListSearchBloc
// ABOUTME: Holds the active query plus the display names matched against it

part of 'follow_list_search_bloc.dart';

/// State emitted by [FollowListSearchBloc].
final class FollowListSearchState extends Equatable {
  /// Creates an immutable state snapshot.
  const FollowListSearchState({
    this.query = '',
    this.candidatePubkeys = const [],
    this.searchTerms = const {},
    this.remoteMatches = const {},
  });

  /// Trimmed search query, or empty when no filter is active.
  ///
  /// Stays empty for inputs shorter than [minSearchQueryLength].
  final String query;

  /// The pubkeys the last query was dispatched against.
  ///
  /// Only used to decide which names still need resolving — the rendered
  /// list is always the one passed to [visibleFrom].
  final List<String> candidatePubkeys;

  /// Lowercased haystack per pubkey: best display name plus handle.
  ///
  /// Grows lazily while a query is active. A pubkey missing from the map
  /// still matches on its generated fallback name.
  final Map<String, String> searchTerms;

  /// Pubkeys the API reported as matching the active query.
  ///
  /// Empty whenever the server-side search could not answer — not deployed,
  /// offline, or the account is not in the API's index. That is why it widens
  /// the on-device match rather than replacing it.
  final Set<String> remoteMatches;

  /// Whether a query is currently filtering the list.
  bool get isActive => query.isNotEmpty;

  /// [pubkeys] filtered by the active query, order preserved.
  ///
  /// Returns [pubkeys] untouched when no query is active, so a list nobody
  /// is searching pays nothing for this call.
  List<String> visibleFrom(List<String> pubkeys) {
    if (query.isEmpty) return pubkeys;
    final needle = query.toLowerCase();
    return pubkeys.where((pubkey) {
      if (remoteMatches.contains(pubkey)) return true;
      final term =
          searchTerms[pubkey] ??
          UserProfile.defaultDisplayNameFor(pubkey).toLowerCase();
      // Pubkeys are lowercase hex, so the lowercased needle compares
      // directly — this lets a pasted hex key find its row.
      return term.contains(needle) || pubkey.startsWith(needle);
    }).toList();
  }

  /// Create a copy with updated values.
  FollowListSearchState copyWith({
    String? query,
    List<String>? candidatePubkeys,
    Map<String, String>? searchTerms,
    Set<String>? remoteMatches,
  }) {
    return FollowListSearchState(
      query: query ?? this.query,
      candidatePubkeys: candidatePubkeys ?? this.candidatePubkeys,
      searchTerms: searchTerms ?? this.searchTerms,
      remoteMatches: remoteMatches ?? this.remoteMatches,
    );
  }

  @override
  List<Object?> get props => [
    query,
    candidatePubkeys,
    searchTerms,
    remoteMatches,
  ];
}
