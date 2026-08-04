// ABOUTME: Events for FollowListSearchBloc
// ABOUTME: Query edits and late-arriving profile repository swaps

part of 'follow_list_search_bloc.dart';

/// Base class for all follow-list search events.
sealed class FollowListSearchEvent {
  const FollowListSearchEvent();
}

/// The user edited the search field.
final class FollowListSearchQueryChanged extends FollowListSearchEvent {
  /// Creates the event for [query] over [candidatePubkeys].
  const FollowListSearchQueryChanged(this.query, this.candidatePubkeys);

  /// Raw text from the search field. Trimmed by the BLoC.
  final String query;

  /// The list currently being searched.
  ///
  /// Carried on the event rather than owned by this BLoC so the rendered
  /// list keeps a single source of truth — the screen's list BLoC. Names are
  /// resolved for these pubkeys only.
  final List<String> candidatePubkeys;
}

/// The Nostr-readiness-gated profile repository resolved or was swapped.
final class FollowListSearchProfileRepositoryChanged
    extends FollowListSearchEvent {
  /// Creates the event carrying the current [repository], if any.
  const FollowListSearchProfileRepositoryChanged(this.repository);

  /// The freshly provided repository, or `null` while Nostr is not ready.
  final ProfileRepository? repository;
}

/// The signed-in user's pubkey resolved or changed.
///
/// Only the own-list screens send this: they address the server-side search
/// with whoever is signed in, and `nostrServiceProvider` hands over a client
/// carrying an empty [pubkey] until auth restore finishes. Without this the
/// BLoC would keep the cold-start empty string and never search server-side.
final class FollowListSearchSubjectPubkeyChanged extends FollowListSearchEvent {
  /// Creates the event carrying the current subject [pubkey].
  const FollowListSearchSubjectPubkeyChanged(this.pubkey);

  /// Whose list this is now, or empty while auth has not restored.
  final String pubkey;
}
