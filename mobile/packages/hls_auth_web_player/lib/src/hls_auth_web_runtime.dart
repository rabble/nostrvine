import 'package:hls_auth_web_player/src/auth_header_provider.dart';

/// Result of a single preflight or fetch attempt.
enum HlsAuthWebAttemptResult {
  /// Source was loaded and attached to the video element.
  ok,

  /// Origin responded 401 / 403. UI should surface the verification flow.
  requiresAuth,

  /// Any other failure. Caller decides whether to fall back.
  failure,
}

/// A thin, test-replaceable port for browser-side work. One implementation
/// uses `dart:js_interop` + hls.js on web; another is an in-memory fake for
/// tests. Keeping the seam here lets the controller stay pure Dart and avoids
/// shipping real JS interop into non-web builds.
abstract class HlsAuthWebRuntime {
  /// Whether this runtime can drive hls.js. On native builds the
  /// implementation returns false so the feature flag can short-circuit.
  bool get isSupported;

  /// Tells the runtime the video element identified by [viewType] exists.
  /// Registers an `HtmlElementView`-compatible factory as a side-effect when
  /// running on web.
  void ensureVideoViewFactory(String viewType);

  /// Fetches the given MP4 [url] with the optional [authorization] header and
  /// pipes the resulting blob URL into the registered video element for
  /// [viewType]. On 401/403 returns [HlsAuthWebAttemptResult.requiresAuth]
  /// without touching the element's `src`.
  Future<HlsAuthWebAttemptResult> loadMp4Blob({
    required String viewType,
    required String url,
    String? authorization,
  });

  /// Wires hls.js to the element for [viewType] using a loader subclass that
  /// calls [authHeader] per request.
  Future<HlsAuthWebAttemptResult> loadHls({
    required String viewType,
    required String url,
    required AuthHeaderProvider authHeader,
  });

  /// Releases any blob URL, hls.js instance, or video element handlers.
  Future<void> dispose(String viewType);
}
