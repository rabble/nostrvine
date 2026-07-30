// ABOUTME: Abstract interface for the app-managed d=notify subscription list.
// ABOUTME: Owns which creators the user gets new-post notifications about.

import 'package:people_lists_repository/src/people_list_publish_result.dart';

/// Repository owning the reserved kind `30000` `d=notify` people list — the
/// set of creators whose new videos the user wants to be notified about
/// ("bells").
///
/// Deliberately separate from `PeopleListsRepository`: the notify list is
/// app-managed and must never be reachable from list-editing UI, so it is
/// excluded from the user-facing list collection by
/// `Nip51PeopleListCodec.reservedDTags`.
///
/// The list is a single NIP-33 replaceable event, so **every** mutation is a
/// full-list republish. Implementations must serialize mutations: two
/// concurrent read-modify-write cycles against the same base event would
/// otherwise let the loser silently drop the winner's change.
///
/// The list is public — anyone can read who the user has subscribed to.
abstract interface class NotifySubscriptionsRepository {
  /// Creators [ownerPubkey] is subscribed to, newest known state.
  ///
  /// Returns an empty set when the user has no notify list yet. Reads are
  /// served from an in-memory snapshot once loaded; call [refresh] to
  /// re-read from relays.
  Future<Set<String>> readSubscriptions({required String ownerPubkey});

  /// Emits the subscription set for [ownerPubkey] on every change.
  ///
  /// Emits the current set immediately on subscribe so a late listener (e.g.
  /// a bell rebuilt after navigation) does not render a stale state.
  Stream<Set<String>> watchSubscriptions({required String ownerPubkey});

  /// Re-reads the notify list from relays, replacing the in-memory snapshot.
  Future<void> refresh({required String ownerPubkey});

  /// Adds [creatorPubkey] and publishes the replacement list.
  ///
  /// Returns [PeopleListPublishStatus.noop] when already subscribed. On
  /// failure the snapshot is left untouched so the caller can revert
  /// optimistic UI.
  Future<PeopleListPublishResult> subscribe({
    required String ownerPubkey,
    required String creatorPubkey,
  });

  /// Removes [creatorPubkey] and publishes the replacement list.
  ///
  /// Returns [PeopleListPublishStatus.noop] when not subscribed, which makes
  /// it safe to call unconditionally from unfollow teardown.
  Future<PeopleListPublishResult> unsubscribe({
    required String ownerPubkey,
    required String creatorPubkey,
  });

  /// Releases stream resources.
  Future<void> dispose();
}
