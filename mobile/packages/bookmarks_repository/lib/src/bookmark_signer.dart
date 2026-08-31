// ABOUTME: Minimal signer contract for publishing the NIP-51 kind-10003 list.
// ABOUTME: Implemented at the app layer by BookmarkSignerAdapter.

import 'package:nostr_sdk/nostr_sdk.dart';

/// Minimal signer contract for reading and publishing the user's NIP-51
/// kind-10003 bookmark list without depending on the app's auth stack.
///
/// Implemented at the app layer by `BookmarkSignerAdapter`, which delegates to
/// `AuthService`. That service already implements the sibling `BlockListSigner`
/// in `nostr_client` for the kind-10000 mute list.
/// Kept deliberately narrow: it needs only [Event] and [NostrSigner] from
/// `nostr_sdk`, so neither this contract nor the repository that consumes it
/// depends on the app.
abstract class BookmarkSigner {
  /// Whether the current user is authenticated and can sign events.
  bool get isAuthenticated;

  /// The signed-in user's public key in hex, or `null` when signed out.
  String? get currentPublicKeyHex;

  /// The active signer, used for the NIP-04/NIP-44 private-item crypto.
  ///
  /// `null` when signed out. Typed as [NostrSigner] rather than the app's
  /// sealed `NostrIdentity` — which implements it — so this contract stays
  /// inside `nostr_sdk`'s type surface.
  NostrSigner? get currentIdentity;

  /// Creates and signs an event, returning `null` when signing fails or the
  /// user is not authenticated.
  ///
  /// [createdAt] overrides the signer's own clock. Kind 10003 is replaceable,
  /// so a publish has to supersede the revision it replaces; two publishes
  /// inside the same second would otherwise sign a tie that NIP-01 is free to
  /// resolve against us (#7629, #7635).
  ///
  /// Implementations are expected to keep the guards the app's signer applies
  /// — notably rejecting an event the signer returned for a different pubkey
  /// (#5450), and verifying the signature of a remote signer's output.
  Future<Event?> createAndSignEvent({
    required int kind,
    required String content,
    List<List<String>>? tags,
    int? createdAt,
  });
}
