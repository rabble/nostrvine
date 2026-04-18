// ABOUTME: Confirms whether a remote media URL is a hard 404 before permanent
// ABOUTME: removal. Prevents transient player errors from deleting valid videos.

import 'package:http/http.dart' as http;

/// A small service that issues a HEAD request to confirm whether a remote
/// media asset is genuinely missing (returns 404) or the player simply
/// failed with a transient error (network flake, slow TLS handshake, etc.).
///
/// Used by the fullscreen feed pipeline before permanently removing a video
/// from all feeds. Without this confirmation the app would eagerly delete
/// valid videos when the player hit a one-off load error.
class MediaAvailabilityChecker {
  /// Creates a checker with an optional injected HTTP [client] for tests.
  const MediaAvailabilityChecker({http.Client? client})
    : _injectedClient = client;

  final http.Client? _injectedClient;

  /// Returns `true` only when a HEAD request to [videoUrl] returns a hard
  /// 404. Any other status (2xx, 3xx, 5xx) or network failure returns
  /// `false` — the caller must treat the error as transient and keep the
  /// video in place.
  ///
  /// When no [client] is injected a throwaway [http.Client] is created and
  /// closed after the request.
  Future<bool> isConfirmedMissing(String videoUrl) async {
    if (videoUrl.isEmpty) return false;
    final client = _injectedClient ?? http.Client();
    try {
      final response = await client.head(Uri.parse(videoUrl));
      return response.statusCode == 404;
    } on Exception {
      return false;
    } finally {
      if (_injectedClient == null) {
        client.close();
      }
    }
  }
}
