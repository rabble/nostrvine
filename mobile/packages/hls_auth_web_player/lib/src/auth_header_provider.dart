/// Async callback that returns a NIP-98 `Authorization` header value for the
/// given media URL, or `null` when no auth header can be produced (for
/// example, when the viewer is not authenticated).
///
/// The returned string, if non-null, MUST be the complete header value,
/// including the scheme prefix — typically `Nostr <base64-json>`.
typedef AuthHeaderProvider =
    Future<String?> Function(String url, String method);

/// HTTP methods accepted by [AuthHeaderProvider]. The loader and MP4 fallback
/// only need `GET`, but the type is kept open for future use.
abstract class AuthHttpMethod {
  /// The HTTP GET method.
  static const String get = 'GET';
}
