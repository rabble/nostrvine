// ABOUTME: Abstract interface for the app-managed d=notify subscription list.
// ABOUTME: Owns which creators the user gets new-post notifications about.

import 'package:people_lists_repository/src/people_list_publish_result.dart';

/// Thrown when the subscription list could not be read from relays.
///
/// Distinct from "the user has no subscriptions": the list is a single
/// replaceable event, so treating an unreadable list as empty and then
/// publishing a replacement would delete every subscription that failed to
/// load. Callers must keep their control disabled rather than assume empty.
class NotifySubscriptionsUnavailableException implements Exception {
  /// Creates an exception for an unreadable list belonging to [ownerPubkey].
  const NotifySubscriptionsUnavailableException(this.ownerPubkey);

  /// Owner whose list could not be read.
  final String ownerPubkey;

  @override
  String toString() =>
      'NotifySubscriptionsUnavailableException: could not read the notify '
      'list for owner $ownerPubkey';
}

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
/// Because a republish is destructive, implementations must also never
/// publish against a base set they failed to read — see
/// [NotifySubscriptionsUnavailableException].
///
/// The list is public — anyone can read who the user has subscribed to.
abstract interface class NotifySubscriptionsRepository {
  /// Creators [ownerPubkey] is subscribed to, newest known state.
  ///
  /// Returns an empty set when the user has no notify list yet. Reads are
  /// served from an in-memory snapshot once loaded; call [refresh] to
  /// re-read from relays.
  ///
  /// Throws [NotifySubscriptionsUnavailableException] when the list could
  /// not be read — an unreachable relay pool is not an empty list.
  Future<Set<String>> readSubscriptions({required String ownerPubkey});

  /// Emits the subscription set for [ownerPubkey] on every change.
  ///
  /// Emits the current set immediately on subscribe so a late listener (e.g.
  /// a bell rebuilt after navigation) does not render a stale state.
  ///
  /// Emits **only** sets that were actually read or published. A failed read
  /// emits nothing, so a listener can keep its control disabled instead of
  /// rendering an unverified "off" that a tap would turn into a destructive
  /// replacement.
  Stream<Set<String>> watchSubscriptions({required String ownerPubkey});

  /// Re-reads the notify list from relays, replacing the in-memory snapshot.
  ///
  /// A failed read leaves the previous snapshot in place rather than
  /// clearing it.
  Future<void> refresh({required String ownerPubkey});

  /// Adds [creatorPubkey] and publishes the replacement list.
  ///
  /// Returns [PeopleListPublishStatus.noop] when already subscribed. On
  /// failure the snapshot is left untouched so the caller can revert
  /// optimistic UI. Returns [PeopleListPublishStatus.failed] without
  /// publishing anything when the current list could not be read.
  Future<PeopleListPublishResult> subscribe({
    required String ownerPubkey,
    required String creatorPubkey,
  });

  /// Removes [creatorPubkey] and publishes the replacement list.
  ///
  /// Returns [PeopleListPublishStatus.noop] when not subscribed, which makes
  /// it safe to call unconditionally from unfollow teardown.
  ///
  /// A failed removal is retained and reapplied by the next mutation or
  /// [reconcile] for the same owner, so an unfollow teardown cannot be
  /// silently lost while the bell that would undo it is unmounted.
  Future<PeopleListPublishResult> unsubscribe({
    required String ownerPubkey,
    required String creatorPubkey,
  });

  /// Republishes the list if any removal is still outstanding.
  ///
  /// Returns [PeopleListPublishStatus.noop] when nothing is pending. Call it
  /// when a subscription surface mounts, so a teardown whose publish failed
  /// is retried instead of waiting for an unrelated toggle.
  Future<PeopleListPublishResult> reconcile({required String ownerPubkey});

  /// Releases stream resources.
  Future<void> dispose();
}
