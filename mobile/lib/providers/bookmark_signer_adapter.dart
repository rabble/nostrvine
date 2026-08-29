// ABOUTME: Adapts AuthService to the bookmarks_repository BookmarkSigner port.
// ABOUTME: Kept out of auth_service.dart, which is a frozen god file (#4338).

import 'package:bookmarks_repository/bookmarks_repository.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/auth_service.dart';

/// Presents [AuthService] as the narrow [BookmarkSigner] the
/// `bookmarks_repository` package depends on.
///
/// `AuthService` implements the sibling `BlockListSigner` directly, and doing
/// the same here would be the obvious move. It is not available:
/// `lib/services/auth_service.dart` is one of the six god files frozen by
/// `check_service_god_file_ceiling.sh` (#4338), and an `implements` clause
/// plus the `@override` annotations it forces grew the file past its ceiling.
/// The ratchet refuses `UPDATE_BASELINE` for growth by design, so the mapping
/// lives here instead — which also keeps the port's shape visible next to the
/// provider that wires it, rather than buried in 4557 lines.
class BookmarkSignerAdapter implements BookmarkSigner {
  /// Wraps [authService].
  const BookmarkSignerAdapter(this._authService);

  final AuthService _authService;

  @override
  bool get isAuthenticated => _authService.isAuthenticated;

  @override
  String? get currentPublicKeyHex => _authService.currentPublicKeyHex;

  @override
  NostrSigner? get currentIdentity => _authService.currentIdentity;

  @override
  Future<Event?> createAndSignEvent({
    required int kind,
    required String content,
    List<List<String>>? tags,
    int? createdAt,
  }) => _authService.createAndSignEvent(
    kind: kind,
    content: content,
    tags: tags,
    createdAt: createdAt,
  );
}
