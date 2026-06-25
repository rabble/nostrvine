/// Canonical error codes emitted by the native player, normalised across
/// Android (Media3 PlaybackException) and iOS (AVFoundation / NSURLError).
///
/// Native code maps platform-specific codes to these string values before
/// sending them over the event channel in the `errorCode` key.
///
/// This lets Dart make reliable, platform-independent retry/failover
/// decisions without string-parsing the raw error message.
enum NativePlayerErrorCode {
  /// HTTP 202 from Divine media while renditions are still processing.
  ///
  /// Android: `ERROR_CODE_IO_BAD_HTTP_STATUS` with response code 202.
  /// iOS: CoreMedia / AVFoundation errors whose message includes HTTP 202.
  mediaProcessing,

  /// HTTP 4xx response from the media server.
  ///
  /// Android: `ERROR_CODE_IO_BAD_HTTP_STATUS` when 400–499.
  /// iOS: `NSError` with HTTP status in `userInfo`.
  httpClientError,

  /// HTTP 5xx response from the media server.
  ///
  /// Android: `ERROR_CODE_IO_BAD_HTTP_STATUS` when 500+.
  /// iOS: `NSError` with HTTP status in `userInfo`.
  httpServerError,

  /// Network is unavailable or the connection was lost before the response
  /// arrived.
  ///
  /// Android: `ERROR_CODE_IO_NETWORK_CONNECTION_FAILED`.
  /// iOS: `NSURLErrorNotConnectedToInternet`,
  /// `NSURLErrorNetworkConnectionLost`.
  networkError,

  /// Connection timed out.
  ///
  /// Android: `ERROR_CODE_IO_NETWORK_CONNECTION_TIMEOUT`.
  /// iOS: `NSURLErrorTimedOut`.
  timeout,

  /// The media container or segment could not be parsed.
  ///
  /// Android: `ERROR_CODE_PARSING_*` (3xxx range).
  /// iOS: `AVErrorUnknown` or format-related AVError codes.
  parseError,

  /// The device's codec/decoder failed.
  ///
  /// Android: `ERROR_CODE_DECODER_*` (4xxx range).
  /// iOS: `AVErrorNoCompatibleAlternatesForExternalDisplay` or decoder errors.
  decoderError,

  /// Any other error that does not fit the categories above.
  unknown;

  /// Whether a source failover should be attempted for this error code.
  ///
  /// This is the routing decision axis: when `true`, callers should advance
  /// to the next source instead of retrying the current one.
  ///
  /// Network / timeout errors are transient and should stay on the same
  /// source. HTTP 4xx/5xx and parse errors indicate the current source is not
  /// usable right now, so the feed should skip to the next available source.
  bool get shouldFailover => switch (this) {
    mediaProcessing => false,
    httpClientError => true,
    httpServerError => true,
    parseError => true,
    networkError => false,
    timeout => false,
    decoderError => false,
    unknown => false,
  };

  /// Whether this error is worth retrying (same source, no failover).
  ///
  /// This is only for same-source retry decisions and must not overlap with
  /// [shouldFailover] for the same error code.
  ///
  /// Transient conditions like network loss or timeout may resolve on retry.
  bool get isTransient => switch (this) {
    mediaProcessing => true,
    networkError => true,
    timeout => true,
    httpServerError => false,
    httpClientError => false,
    parseError => false,
    decoderError => false,
    unknown => false,
  };

  /// Parses the string value sent over the platform channel.
  static NativePlayerErrorCode fromString(String value) => switch (value) {
    'media_processing' => mediaProcessing,
    'http_client_error' => httpClientError,
    'http_server_error' => httpServerError,
    'network_error' => networkError,
    'timeout' => timeout,
    'parse_error' => parseError,
    'decoder_error' => decoderError,
    _ => unknown,
  };
}
