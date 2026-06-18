import 'dart:async';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:openvine/models/viewer_auth_result.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';

/// Creates viewer auth headers for media GET requests.
class MediaViewerAuthService {
  MediaViewerAuthService({
    required AuthService authService,
    required BlossomAuthService blossomAuthService,
    required Nip98AuthService nip98AuthService,
  }) : _authService = authService,
       _blossomAuthService = blossomAuthService,
       _nip98AuthService = nip98AuthService;

  final AuthService _authService;
  final BlossomAuthService _blossomAuthService;
  final Nip98AuthService _nip98AuthService;

  /// Caller-side bound on remote viewer-auth signing. Sits well under
  /// Keycast's 30s RPC ceiling (`keycast_rpc.dart`) yet far above the observed
  /// ~200-430ms happy-path round-trip, so a healthy signer is never cut off
  /// while an unreachable one fails fast into the existing retry UI.
  static const Duration _signTimeout = Duration(seconds: 6);

  /// Whether viewer auth headers can be created at all (the user is
  /// authenticated).
  ///
  /// This is a synchronous gate, not a signer-reachability check — a live
  /// probe would itself hang on the same remote RPC. The [createAuthHeaders]
  /// timeout is the de-facto reachability proxy for remote signers.
  bool get canCreateHeaders => _authService.isAuthenticated;

  /// Creates viewer-auth headers for a media GET.
  ///
  /// For the Keycast OAuth-only remote signer, the signing round-trip is
  /// bounded by [_signTimeout]; if the signer does not respond in time this
  /// returns [ViewerAuthSignerUnreachable] — distinct from the
  /// [ViewerAuthUnavailable] "no headers" result — rather than hanging on
  /// Keycast's 30s ceiling. Local and interactive remote signers (bunker /
  /// Amber / NIP-07) are awaited unbounded so a human approval step is never
  /// cut off.
  Future<ViewerAuthResult> createAuthHeaders({
    String? sha256Hash,
    String? url,
    String? serverUrl,
  }) async {
    if (!_authService.isAuthenticated) {
      return const ViewerAuthUnavailable();
    }

    final boundSigning =
        _authService.currentIdentity?.signsRemotelyNonInteractive ?? false;

    try {
      if (sha256Hash != null && sha256Hash.isNotEmpty) {
        final header = await _bound(
          boundSigning,
          () => _blossomAuthService.createGetAuthHeader(
            sha256Hash: sha256Hash,
            serverUrl: serverUrl,
          ),
        );
        return _result(header);
      }

      if (url != null && url.isNotEmpty) {
        final token = await _bound(
          boundSigning,
          () => _nip98AuthService.createAuthToken(
            url: url,
            method: HttpMethod.get,
          ),
        );
        return _result(token?.authorizationHeader);
      }
    } on TimeoutException {
      return const ViewerAuthSignerUnreachable();
    }

    return const ViewerAuthUnavailable();
  }

  /// Awaits [sign]. When [bound] (the non-interactive remote signer), the call
  /// is capped at [_signTimeout]; the [TimeoutException] propagates to
  /// [createAuthHeaders], which maps it to [ViewerAuthSignerUnreachable]
  /// instead of hanging on the remote RPC's own 30s ceiling. Unbounded
  /// otherwise, so a local or interactive (human-approved) sign is never cut
  /// off.
  Future<T?> _bound<T>(bool bound, Future<T?> Function() sign) async {
    if (!bound) return sign();
    return sign().timeout(_signTimeout);
  }

  ViewerAuthResult _result(String? authorizationHeader) {
    if (authorizationHeader == null || authorizationHeader.isEmpty) {
      return const ViewerAuthUnavailable();
    }

    return ViewerAuthAuthorized({'Authorization': authorizationHeader});
  }
}
