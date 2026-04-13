// ABOUTME: Abstract auth interface for Blossom services.
// ABOUTME: Decouples the package from the app's AuthService and nostr_sdk.

/// A signed Nostr event for Blossom BUD-01 authentication.
///
/// Wraps the event as a JSON-serializable map, avoiding a direct
/// dependency on any specific Nostr SDK implementation.
class BlossomSignedEvent {
  /// Creates a signed event wrapper from its JSON representation.
  const BlossomSignedEvent({required this.json});

  /// The full signed event as a JSON-serializable map.
  ///
  /// Expected keys: `id`, `pubkey`, `created_at`, `kind`, `tags`,
  /// `content`, `sig`.
  final Map<String, dynamic> json;
}

/// Minimal authentication interface required by Blossom services.
///
/// The host app implements this by wrapping its auth service (e.g.
/// `AuthService`) in an adapter class.
abstract class BlossomAuthProvider {
  /// Whether the current user is authenticated and can sign events.
  bool get isAuthenticated;

  /// Creates and signs a kind-24242 Nostr event for Blossom auth.
  ///
  /// Returns `null` if signing fails or the user is not authenticated.
  Future<BlossomSignedEvent?> createAndSignEvent({
    required int kind,
    required String content,
    required List<List<String>> tags,
  });
}
