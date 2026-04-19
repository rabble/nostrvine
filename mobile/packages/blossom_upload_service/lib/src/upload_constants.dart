// ABOUTME: Named constants for the Divine resumable upload protocol
// ABOUTME: Eliminates repeated header and extension token literals across
// service code and tests

/// HTTP header names for the Divine resumable upload protocol.
///
/// Used during capability discovery (`HEAD /upload`) and the resumable
/// upload session lifecycle (chunk PUT, session query, completion).
///
/// See `docs/protocol/blossom/2026-03-26-divine-resumable-upload-sessions-bud.md`
class DivineUploadHeaders {
  /// Comma-separated list of supported upload extensions.
  ///
  /// Advertised by `HEAD /upload` response.
  static const String extensions = 'X-Divine-Upload-Extensions';

  /// Control-plane host for session management (init, complete, query).
  ///
  /// Advertised by `HEAD /upload` response.
  static const String controlHost = 'X-Divine-Upload-Control-Host';

  /// Data-plane host that receives chunk upload traffic.
  ///
  /// Advertised by `HEAD /upload` response.
  static const String dataHost = 'X-Divine-Upload-Data-Host';

  /// Current byte offset acknowledged by the server.
  ///
  /// Returned in chunk upload and session query responses.
  static const String uploadOffset = 'Upload-Offset';

  /// ISO-8601 timestamp when the upload session expires.
  ///
  /// Returned in chunk upload and session query responses.
  static const String uploadExpiresAt = 'Upload-Expires-At';
}

/// Capability tokens advertised in [DivineUploadHeaders.extensions].
class DivineUploadExtensions {
  /// Resumable upload sessions with chunked transfer.
  static const String resumableSessions = 'resumable-sessions';
}
