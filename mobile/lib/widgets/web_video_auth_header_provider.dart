// ABOUTME: Builds the async AuthHeaderProvider closure wired into the web
// ABOUTME: HLS auth player, backed by MediaViewerAuthService.

import 'package:hls_auth_web_player/hls_auth_web_player.dart'
    show AuthHeaderProvider;
import 'package:openvine/services/media_viewer_auth_service.dart';

/// Re-export of the [AuthHeaderProvider] signature from
/// `hls_auth_web_player` so callers in the `openvine` package don't need
/// to import the package directly.
typedef WebVideoAuthHeaderProvider = AuthHeaderProvider;

/// Builds an [AuthHeaderProvider] closure that delegates to
/// [MediaViewerAuthService] for NIP-98 signing.
///
/// The returned callback:
/// * Returns `null` when the viewer cannot create auth headers (not
///   authenticated or not age-verified). The `HlsAuthWebPlayer` treats a
///   `null` result as "no auth available", which for a 401-gated origin
///   surfaces `requiresAuth` to the overlay layer.
/// * Extracts the `sha256` hash and origin server from [url] so the
///   Blossom-style GET auth endpoint picks the right signing path.
///
/// The widget layer calls this once per item with the current URL when
/// constructing the player. Per-segment signing happens inside the hls.js
/// loader via the returned closure.
WebVideoAuthHeaderProvider buildWebVideoAuthHeaderProvider(
  MediaViewerAuthService service,
) {
  return (String url, String method) async {
    // Only GET requests are ever made by the hls loader + MP4 fallback.
    // The method param is kept for future use.
    final headers = await service.createAuthHeaders(
      sha256Hash: _extractSha256FromUrl(url),
      url: url,
      serverUrl: _extractServerUrl(url),
    );
    return headers?['Authorization'];
  };
}

/// Extracts a 64-character hex sha256 segment from a Blossom-style URL, or
/// `null` if the URL doesn't carry one.
String? _extractSha256FromUrl(String url) {
  try {
    final uri = Uri.parse(url);
    for (final segment in uri.pathSegments.reversed) {
      final cleanSegment = segment.split('.').first;
      if (cleanSegment.length == 64 &&
          RegExp(r'^[a-fA-F0-9]+$').hasMatch(cleanSegment)) {
        return cleanSegment.toLowerCase();
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}

/// Returns the `scheme://host[:port]` origin for [url], or `null` if [url]
/// is not a valid URI.
String? _extractServerUrl(String url) {
  try {
    final uri = Uri.parse(url);
    final portSuffix = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$portSuffix';
  } catch (_) {
    return null;
  }
}
