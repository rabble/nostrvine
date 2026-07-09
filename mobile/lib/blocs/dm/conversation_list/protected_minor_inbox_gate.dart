// ABOUTME: Inbound DM filter seam for the protected-minor restriction (#176).
// ABOUTME: Mirrors the blocklist filter — the app injects an implementation that
// ABOUTME: hides conversations a protected minor may not see, and re-fires on
// ABOUTME: receive-time revalidation so a revoked counterparty drops from the list.

import 'package:models/models.dart';

/// Filters the inbound conversation list for a protected minor (#176).
///
/// When the current user is a restricted protected minor, only conversations
/// whose EVERY non-self participant is an approved official recipient are
/// visible (a group needs all participants approved, else an attacker could
/// p-tag the minor with a pinned decoy). For a non-restricted user this is a
/// pass-through.
abstract interface class ProtectedMinorInboxGate {
  /// Returns [conversations] filtered to those the current user may see. May
  /// kick receive-time revalidation of the counterparties as a side effect, so
  /// a server-side revocation is pulled into the sync verdict; a resulting
  /// verdict flip is signalled on [changes].
  List<DmConversation> filter(
    List<DmConversation> conversations, {
    required String userPubkey,
  });

  /// Emits when a revalidation flips a counterparty's verdict, so the list
  /// re-filters. A non-restricted gate may never emit.
  Stream<void> get changes;

  /// Signals that the DM-restriction status itself may have flipped
  /// (mid-session approval/revocation), surfaced on [changes] so an
  /// already-settled list and the unread badge re-filter without waiting for
  /// the next DM event.
  void notifyRestrictionChanged();
}
