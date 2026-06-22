import 'package:nostr_sdk/event.dart';

/// Minimal signer interface required by `ContentBlocklistRepository` for
/// publishing the user's mute/block lists to Nostr — the standard NIP-51
/// kind 10000 mute list and the legacy kind 30000 (d=block) list.
///
/// In production this is implemented by the app-level `AuthService`. The
/// interface is kept intentionally narrow so the package has no dependency
/// on the app's auth stack — only on [Event] from `nostr_sdk`.
abstract class BlockListSigner {
  /// Whether the current user is authenticated and can sign events.
  bool get isAuthenticated;

  /// Creates and signs a Nostr event with the given [kind], [content], and
  /// [tags]. Returns `null` if signing fails or the user is not
  /// authenticated.
  Future<Event?> createAndSignEvent({
    required int kind,
    required String content,
    List<List<String>>? tags,
  });
}
