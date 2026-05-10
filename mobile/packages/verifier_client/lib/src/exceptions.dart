// ABOUTME: Typed exceptions thrown by VerifierClient.

/// Base class for all errors thrown by the verifier client.
sealed class VerifierClientException implements Exception {
  /// Creates a verifier exception with a human-readable [message].
  const VerifierClientException(this.message, this.kind);

  /// Free-form message describing the failure.
  final String message;

  /// Stable identifier for the exception subtype, safe for production logs.
  final String kind;

  @override
  String toString() => '$kind: $message';
}

/// HTTP non-2xx response from the verifier.
final class VerifierApiException extends VerifierClientException {
  /// Creates a [VerifierApiException] with the response [statusCode].
  const VerifierApiException(this.statusCode, String message)
    : super(message, 'VerifierApiException');

  /// The HTTP status code returned by the verifier.
  final int statusCode;
}

/// Request did not complete within the configured timeout.
final class VerifierTimeoutException extends VerifierClientException {
  /// Creates a [VerifierTimeoutException] with [message].
  const VerifierTimeoutException(String message)
    : super(message, 'VerifierTimeoutException');
}

/// Network or transport error before a response could be read.
final class VerifierNetworkException extends VerifierClientException {
  /// Creates a [VerifierNetworkException] with [message].
  const VerifierNetworkException(String message)
    : super(message, 'VerifierNetworkException');
}
