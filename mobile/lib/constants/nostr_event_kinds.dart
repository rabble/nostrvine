// ABOUTME: Named constants for standard Nostr event kinds used in the app
// ABOUTME: Eliminates magic numbers for event kinds across the codebase

/// Standard Nostr event kinds used by the app.
///
/// See https://github.com/nostr-protocol/nips for the full list.
class NostrEventKinds {
  /// Kind 0: User metadata (NIP-01)
  static const int metadata = 0;

  /// Kind 3: Contact list / follows (NIP-02)
  static const int contactList = 3;

  /// Kind 7: Reaction (NIP-25)
  static const int reaction = 7;
}
