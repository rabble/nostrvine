// ABOUTME: Classifies why a remote media URL failed before any permanent
// ABOUTME: removal. Separates "gone" from "needs auth" from transient errors.

import 'package:http/http.dart' as http;

/// Why a remote media asset could not be fetched anonymously.
///
/// The distinction matters because Divine's media host answers with different
/// statuses for very different situations, and only one of them justifies
/// permanently pruning a video (see #5953).
enum MediaAvailability {
  /// The HEAD request succeeded — the media is retrievable anonymously.
  available,

  /// HEAD returned a hard **404**.
  ///
  /// Blossom collapses `Banned`, `Deleted`, `Restricted` *and* genuinely-absent
  /// metadata into this one status, so it means "not retrievable", which is not
  /// the same as "the bytes are gone". It is still the only status that
  /// justifies a persistent prune, because none of those cases become
  /// retrievable by authenticating.
  missing,

  /// HEAD returned **401** or **403** — the media exists but is gated on who is
  /// asking, so an anonymous probe cannot tell whether it is retrievable.
  ///
  /// The two statuses are gated differently, and neither may be persisted as
  /// broken:
  ///
  /// * **401** is blossom's age gate. `access_for` maps `AgeRestricted` to
  ///   `AgeGated` and grants access as soon as the request carries a pubkey, so
  ///   an authenticated retry can succeed. The app models this elsewhere as
  ///   `VideoErrorType.ageRestricted`.
  /// * **403** is moderation-restricted (`VideoErrorType.forbidden`) and is
  ///   *not* fixed by authenticating. Blossom's `access_for` never returns it —
  ///   it comes from layers above — so it is folded in here only because it is
  ///   likewise not evidence that the media is gone.
  authRequired,

  /// Any other status, or a network failure. Treat as transient.
  unknown,
}

/// A small service that issues a HEAD request to classify why a remote media
/// asset failed to load, rather than assuming the player's error string.
///
/// Used before permanently removing a video from all feeds. Without this
/// confirmation the app would eagerly delete valid videos when the player hit a
/// one-off load error, or hide age-restricted videos the viewer is entitled to
/// watch.
class MediaAvailabilityChecker {
  /// Creates a checker with an optional injected HTTP [client] for tests.
  const MediaAvailabilityChecker({http.Client? client})
    : _injectedClient = client;

  final http.Client? _injectedClient;

  /// Classifies [videoUrl] by issuing an anonymous HEAD request.
  ///
  /// An empty URL, and any exception, classify as [MediaAvailability.unknown]
  /// so the caller keeps the item.
  ///
  /// When no `client` is injected a throwaway [http.Client] is created and
  /// closed after the request.
  Future<MediaAvailability> check(String videoUrl) async {
    if (videoUrl.isEmpty) return MediaAvailability.unknown;
    final client = _injectedClient ?? http.Client();
    try {
      final response = await client.head(Uri.parse(videoUrl));
      final status = response.statusCode;
      if (status >= 200 && status < 300) return MediaAvailability.available;
      if (status == 404) return MediaAvailability.missing;
      if (status == 401 || status == 403) return MediaAvailability.authRequired;
      return MediaAvailability.unknown;
    } on Exception {
      return MediaAvailability.unknown;
    } finally {
      if (_injectedClient == null) {
        client.close();
      }
    }
  }

  /// Returns `true` only when [videoUrl] is a HEAD-confirmed hard 404.
  ///
  /// Any other status — including the 401 age gate — and any network failure
  /// return `false`, so the caller keeps the video in place.
  Future<bool> isConfirmedMissing(String videoUrl) async =>
      await check(videoUrl) == MediaAvailability.missing;
}
